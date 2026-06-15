import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String username;
  final String bio;
  final String profilePhotoUrl;
  final String coverPhotoUrl;

  const ProfileHeader({
    Key? key,
    required this.name,
    required this.username,
    required this.bio,
    required this.profilePhotoUrl,
    required this.coverPhotoUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          width: double.infinity,
          child: coverPhotoUrl.isEmpty
              ? Container(color: const Color(0xFFE9E0FA))
              : CachedNetworkImage(imageUrl: coverPhotoUrl, fit: BoxFit.cover),
        ),
        Transform.translate(
          offset: const Offset(0, -38),
          child: CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 38,
              backgroundImage: profilePhotoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(profilePhotoUrl)
                  : const AssetImage('assets/images/Profile.png') as ImageProvider,
            ),
          ),
        ),
        Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
        if (username.isNotEmpty)
          Text('@$username', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
        if (bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              bio,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
      ],
    );
  }
}
