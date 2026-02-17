import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:paperless_mobile/core/global/asset_images.dart';
import 'package:paperless_mobile/features/settings/view/widgets/biometric_authentication_setting.dart';
import 'package:paperless_mobile/features/settings/view/widgets/language_selection_setting.dart';
import 'package:paperless_mobile/features/settings/view/widgets/theme_mode_setting.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

class ApplicationIntroSlideshow extends StatefulWidget {
  const ApplicationIntroSlideshow({super.key});

  @override
  State<ApplicationIntroSlideshow> createState() =>
      _ApplicationIntroSlideshowState();
}

class _ApplicationIntroSlideshowState extends State<ApplicationIntroSlideshow> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: IntroductionScreen(
        globalBackgroundColor: Theme.of(context).canvasColor,
        showDoneButton: true,
        next: Text(S.of(context)!.next),
        done: Text(S.of(context)!.done),
        onDone: () {
          Navigator.pop(context);
        },
        dotsDecorator: DotsDecorator(
          color: Theme.of(context).colorScheme.onSurface,
          activeColor: Theme.of(context).colorScheme.primary,
          activeSize: const Size(16.0, 8.0),
          activeShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(25.0)),
          ),
        ),
        pages: [
          PageViewModel(
            titleWidget: Text(
              S.of(context)!.introSlideOrganizeTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            image: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image(image: AssetImages.organizeDocuments.image),
            ),
            bodyWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  S.of(context)!.introSlideOrganizeBody,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          PageViewModel(
            titleWidget: Text(
              S.of(context)!.introSlideSecureTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            image: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image(image: AssetImages.secureDocuments.image),
            ),
            bodyWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  S.of(context)!.introSlideSecureBody,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          PageViewModel(
            titleWidget: Text(
              S.of(context)!.introSlideDoneTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            image: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image(image: AssetImages.success.image),
            ),
            bodyWidget: const Column(
              children: [
                BiometricAuthenticationSetting(),
                LanguageSelectionSetting(),
                ThemeModeSetting(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
