abstract interface class LocalVolumeStore {
  Future<double> read();

  Future<void> write(double volume);
}
