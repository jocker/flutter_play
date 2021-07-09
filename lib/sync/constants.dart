enum SyncSchemaOp { RemoteRead, RemoteWrite }
enum SyncObjectOp { None, Create, Update, Delete }
enum SyncObjectPersistenceState {
  Unknown,
  LocalOnly /*object only exists in the local db*/,
  RemoteAndLocal /* object exists both locally and remotely */
}
