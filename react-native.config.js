module.exports = {
  dependencies: {
    'react-native-beep-player': {
      root: __dirname,
      platforms: {
        android: {
          sourceDir: './android',
          packageImportPath: 'import com.beepplayer.BeepPlayerPackage;',
          packageInstance: 'new BeepPlayerPackage()',
        },
        ios: {
          podspecPath: './react-native-beep-player.podspec',
          sourceDir: './ios',
        },
      },
    },
  },
};
