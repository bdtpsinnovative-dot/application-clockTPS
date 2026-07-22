import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/work_ui.dart';

class CompanyWebsitesPage extends StatelessWidget {
  const CompanyWebsitesPage({super.key});

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        final fallbackLaunched = await launchUrl(url, mode: LaunchMode.platformDefault);
        if (!fallbackLaunched) {
          await launchUrl(url);
        }
      }
    } catch (_) {
      try {
        await launchUrl(url);
      } catch (err) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ไม่สามารถเปิดลิงก์: $urlString ได้')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: workBackground,
      appBar: AppBar(
        title: const Text(
          'เว็บไซต์ในเครือของบริษัท',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: workText),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: workText),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: SizedBox(
          height: 185,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildBannerCard(
                context,
                imagePath: 'assets/images/banner_zenslab.webp',
                url: 'https://www.zen-slab.com',
                title: 'Zen Slab',
                description: 'เราเริ่มต้นจากแก่นแท้ของต้นไม้ คุณค่าที่สำคัญที่สุดคือความเป็นธรรมชาติ...',
              ),
              _buildBannerCard(
                context,
                imagePath: 'assets/images/banner_wallcraft.webp',
                url: 'https://wallcraftthailand.com',
                title: 'Wallcraft Thailand',
                description: 'Wallcraft ศูนย์รวมสินค้าผนังและระแนงไม้คุณภาพสูง',
              ),
              _buildBannerCard(
                context,
                imagePath: 'assets/images/banner_terrahome.webp',
                url: 'https://terrahome-studio.com',
                title: 'Terra Home Studio',
                description: 'ของตกแต่งบ้าน ดีไซน์มินิมอล สไตล์ wabi-sabi',
              ),
              _buildBannerCard(
                context,
                imagePath: 'assets/images/banner_emberash.webp',
                url: 'https://emberandashliving.vercel.app/',
                title: 'Ember & Ash Living',
                description: 'เฟอร์นิเจอร์ดีไซน์พรีเมียม สไตล์โมเดิร์นร่วมสมัย',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerCard(
    BuildContext context, {
    required String imagePath,
    required String url,
    required String title,
    required String description,
  }) {
    return GestureDetector(
      onTap: () => _launchUrl(context, url),
      child: Container(
        width: 175,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  imagePath,
                  width: 175,
                  height: 110,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: workText,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: workMuted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
