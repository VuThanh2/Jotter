enum NotePermission {
  view('ReadOnly', 'Can view'),
  edit('Edit', 'Can edit');

  const NotePermission(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static NotePermission fromApi(String value) =>
      value == edit.apiValue ? edit : view;
}
