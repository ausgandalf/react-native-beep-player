declare module 'react-native-beep-player' {
  interface BeepPlayerInterface {
    start(bpm: number, filename: string): void;
    stop(): void;
    mute(value: boolean): void;
  }

  const BeepPlayer: BeepPlayerInterface;
  export default BeepPlayer;
}
