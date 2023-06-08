public class Database {

  private Sqlite.Database? _db      = null;
  private string           _db_file = GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "test.db" );

  /* Default constructor */
  public Database() {

    var jdir = GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler" );
    if( DirUtils.create_with_parents( jdir, 0775 ) == 0 ) {
      stdout.printf( "That worked!\n" );
    }

    // Generate the database file pathname
    _db_file = GLib.Path.build_filename( jdir, "test.db" );

    // Open the database
    var err = Sqlite.Database.open( _db_file, out _db );
    if( err != Sqlite.OK ) {
      stderr.printf( "ERROR:  Unable to open database: %s\n", _db.errmsg() );
    }

    // Check to see if the file is empty
    string[] res;
    string   errmsg;
    int nrows, ncols;
    var query = "SELECT * FROM Entries";
    err = _db.get_table( query, out res, out nrows, out ncols, out errmsg );
    if( err != Sqlite.OK ) {
      stdout.printf( "Entries table exists\n" );
    } else {
      stdout.printf( "Entries table does not exist\n" );
    }

  }

}
