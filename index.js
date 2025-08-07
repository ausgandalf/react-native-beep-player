import { NativeModules } from 'react-native';
const { BeepPlayer } = NativeModules;

export default {
  start: (bpm, file) => BeepPlayer.start(bpm, file),
  stop: () => BeepPlayer.stop(),
};
