const crypto = require('crypto');
const nodemailer = require('nodemailer');
const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

const OTP_TTL_MS = 10 * 60 * 1000;
const RESEND_COOLDOWN_MS = 45 * 1000;
const MAX_ATTEMPTS = 5;
const OTP_COLLECTION = 'loginOtps';

const publicCallable = {
  cors: true,
  invoker: 'public',
  region: 'us-central1',
};

function otpDocId(email) {
  return crypto.createHash('sha256').update(email).digest('hex');
}

function hashOtp(otp, salt) {
  return crypto.createHmac('sha256', salt).update(otp).digest('hex');
}

function hashesMatch(a, b) {
  const left = Buffer.from(String(a));
  const right = Buffer.from(String(b));
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

async function findAuthUser(identifier) {
  const id = String(identifier || '').trim();
  if (!id) {
    throw new HttpsError('invalid-argument', 'Enter your username, mobile or email.');
  }

  const db = admin.firestore();

  if (id.includes('@')) {
    try {
      const user = await admin.auth().getUserByEmail(id.toLowerCase());
      return { uid: user.uid, email: user.email };
    } catch (err) {
      if (err.code !== 'auth/user-not-found') throw err;
    }
    const byEmail = await db
      .collection('users')
      .where('email', '==', id.toLowerCase())
      .limit(1)
      .get();
    if (!byEmail.empty) {
      const email = byEmail.docs[0].data().email;
      if (typeof email === 'string' && email.includes('@')) {
        const user = await admin.auth().getUserByEmail(email.toLowerCase());
        return { uid: user.uid, email: user.email };
      }
    }
    throw new HttpsError('not-found', 'User not found.');
  }

  let snap = await db.collection('users').where('username', '==', id).limit(1).get();
  if (snap.empty) {
    snap = await db.collection('users').where('mobile', '==', id).limit(1).get();
  }
  if (snap.empty) {
    throw new HttpsError('not-found', 'User not found.');
  }
  const email = snap.docs[0].data().email;
  if (typeof email !== 'string' || !email.includes('@')) {
    throw new HttpsError('failed-precondition', 'Account has no email on file.');
  }
  try {
    const user = await admin.auth().getUserByEmail(email.toLowerCase());
    return { uid: user.uid, email: user.email };
  } catch (err) {
    throw new HttpsError('not-found', 'User not found.');
  }
}

function mailerFromEnv() {
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  if (!user || !pass) {
    throw new HttpsError(
      'failed-precondition',
      'Email OTP is not configured. Set SMTP_USER and SMTP_PASS on Cloud Functions.',
    );
  }
  const host = process.env.SMTP_HOST || 'smtp.gmail.com';
  const port = Number(process.env.SMTP_PORT || 465);
  return {
    transporter: nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
    }),
    from: process.env.MAIL_FROM || `Halo <${user}>`,
  };
}

async function sendOtpEmail(to, otp) {
  const { transporter, from } = mailerFromEnv();
  await transporter.sendMail({
    from,
    to,
    subject: 'Your Halo login code',
    text: `Your Halo login OTP is ${otp}. It expires in 10 minutes.`,
    html: `<p>Your Halo login OTP is <strong>${otp}</strong>.</p><p>It expires in 10 minutes.</p>`,
  });
}

exports.sendLoginOtp = onCall(publicCallable, async (request) => {
  const { uid, email } = await findAuthUser(request.data && request.data.identifier);
  const normalized = String(email).trim().toLowerCase();
  const ref = admin.firestore().collection(OTP_COLLECTION).doc(otpDocId(normalized));
  const existing = await ref.get();
  const now = Date.now();
  if (existing.exists) {
    const lastSent = existing.data().sentAt || 0;
    if (now - lastSent < RESEND_COOLDOWN_MS) {
      throw new HttpsError('resource-exhausted', 'Please wait before requesting another OTP.');
    }
  }

  const otp = String(crypto.randomInt(100000, 1000000));
  const salt = crypto.randomBytes(16).toString('hex');
  await ref.set({
    uid,
    email: normalized,
    hash: hashOtp(otp, salt),
    salt,
    sentAt: now,
    expiresAt: now + OTP_TTL_MS,
    attempts: 0,
  });

  try {
    await sendOtpEmail(normalized, otp);
  } catch (err) {
    await ref.delete();
    if (err instanceof HttpsError) throw err;
    console.error('sendLoginOtp mail failed', err);
    throw new HttpsError('internal', 'Could not send OTP email.');
  }
  return { sent: true };
});

exports.verifyLoginOtp = onCall(publicCallable, async (request) => {
  const otp = String((request.data && request.data.otp) || '').trim();
  if (!/^\d{6}$/.test(otp)) {
    throw new HttpsError('invalid-argument', 'Enter the 6-digit OTP.');
  }

  const { uid, email } = await findAuthUser(request.data && request.data.identifier);
  const normalized = String(email).trim().toLowerCase();
  const ref = admin.firestore().collection(OTP_COLLECTION).doc(otpDocId(normalized));
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'OTP expired. Request a new one.');
  }

  const data = snap.data();
  const now = Date.now();
  if (now > (data.expiresAt || 0)) {
    await ref.delete();
    throw new HttpsError('deadline-exceeded', 'OTP expired. Request a new one.');
  }
  if ((data.attempts || 0) >= MAX_ATTEMPTS) {
    await ref.delete();
    throw new HttpsError('resource-exhausted', 'Too many attempts. Request a new OTP.');
  }
  if (data.uid !== uid || !hashesMatch(data.hash, hashOtp(otp, data.salt))) {
    await ref.update({ attempts: admin.firestore.FieldValue.increment(1) });
    throw new HttpsError('permission-denied', 'Invalid OTP.');
  }

  await ref.delete();
  const token = await admin.auth().createCustomToken(uid);
  return { token };
});
