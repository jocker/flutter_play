enum SyncSchemaOp { RemoteRead, RemoteWrite, RemoteNone }
enum SyncObjectMutationType { None, Create, Update, Delete }
enum SyncObjectPersistenceState {
  Unknown,
  LocalOnly /*object only exists in the local db*/,
  RemoteAndLocal /* object exists both locally and remotely */
}

enum SortDirection { None, Asc, Desc }

enum SyncStorageType { Local, Remote }

SortDirection getNextSortDirection(SortDirection current) {
  int nextIndex = current.index + 1;
  if (nextIndex >= SortDirection.values.length) {
    nextIndex = 0;
  }
  return SortDirection.values[nextIndex];
}
