public class DBEntry {

  public string title { get; set; default = ""; }
  public string text  { get; set; default = ""; }
  public string date  { get; set; default = ""; }

  /* Default constructor */
  public DBEntry() {
    this.date = todays_date();
  }

  /* Constructor */
  public DBEntry.for_save( string title, string text ) {
    this.title = title;
    this.text  = text;
    this.date  = todays_date();
  }

  /* Constructor */
  public DBEntry.for_list( string title, string date ) {
    this.title = title;
    this.date  = date;
  }

  /* Constructor */
  public DBEntry.with_date( string title, string text, string date ) {
    this.title = title;
    this.text  = text;
    this.date  = date;
  }

  /* Returns the title of this entry */
  public string gen_title() {
    return( (this.title == "") ? _( "Entry for %s" ).printf( this.date ) : this.title );
  }

  /* Returns the current year */
  public int get_year() {
    var date_bits = date.split( "-" );
    return( int.parse( date_bits[0] ) );
  }

  /* Returns the current month */
  public int get_month() {
    var date_bits = date.split( "-" );
    return( int.parse( date_bits[1] ) );
  }

  /* Returns the date in DateTime form */
  public uint get_day() {
    var date_bits = date.split( "-" );
    return( (uint)int.parse( date_bits[2] ) );
  }

  /* Returns the string version of today's date */
  public static string todays_date() {
    var today = new DateTime.now_local();
    return( datetime_date( today ) );
  }

  /* Returns the string date for the given DateTime object */
  public static string datetime_date( DateTime date ) {
    return( "%04d-%02d-%02d".printf( date.get_year(), date.get_month(), date.get_day_of_month() ) );
  }
 
  /* Compares two DBEntries for sorting purposes (by date) */
  public static int compare( void* x, void* y ) {
    DBEntry** x1 = (DBEntry**)x;
    DBEntry** y1 = (DBEntry**)y;
    return( strcmp( (string)((*y1)->date), (string)((*x1)->date ) ) );
  }

  public string to_string() {
    return( "title: %s, text: %s, date: %s".printf( title, text, date ) );
  }

}

public class Database {

  private Sqlite.Database? _db      = null;
  private string           _db_file = GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "test.db" );

  /* Default constructor */
  public Database() {

    var dir = GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "db" );
    DirUtils.create_with_parents( dir, 0775 );

    // Generate the database file pathname
    _db_file = GLib.Path.build_filename( dir, "test.db" );

    // Open the database
    var err = Sqlite.Database.open( _db_file, out _db );
    if( err != Sqlite.OK ) {
      stderr.printf( "ERROR:  Unable to open database: %s\n", _db.errmsg() );
    }

    if( !create_tables() ) {
      stdout.printf( "ERROR:  Creating database tables\n" );
    }

  }

  /* Creates the database tables if they do not already exist */
  private bool create_tables() {

    // Create the table if it doesn't already exist
    var query = """
      CREATE TABLE IF NOT EXISTS Entry (
        id    INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
        title TEXT                              NOT NULL,
        txt   TEXT                              NOT NULL,
        date  TEXT                              NOT NULL
      );
      """;

    string errmsg;
    var err = _db.exec( query, null, out errmsg );
    if( err != Sqlite.OK ) {
      stdout.printf( "create table issue, err: %d, errmsg: %s\n", err, errmsg );
      return( false );
    }

    return( true );

  }

  /* Returns the list of all entries to be displayed in the listbox */
  public bool get_all_entries( ref Array<DBEntry> entries ) {

    Sqlite.Statement stmt;

    var query = "SELECT * FROM Entry;";
    var err = _db.prepare_v2( query, query.length, out stmt );
    if( err != Sqlite.OK ) {
      return( false );
    }

    while( stmt.step() == Sqlite.ROW ) {
      var entry = new DBEntry.for_list( stmt.column_text( 1 ), stmt.column_text( 3 ) );
      entries.append_val( entry );
    }

    /* Sort based on date */
    entries.sort( (CompareFunc)DBEntry.compare );

    return( true );

  }

  /* Creates a new entry with the given date if one could not be found */
  private bool create_entry( ref DBEntry entry ) {

    var query = """
      INSERT INTO Entry (title, txt, date) VALUES ('', '', '%s');
      """.printf( entry.date );

    string errmsg;
    var err = _db.exec( query, null, out errmsg );
    if( err != Sqlite.OK ) {
      stdout.printf( "err: %d, errmsg: %s\n", err, errmsg );
      return( false );
    }

    return( true );

  }

  /* Retrieves the text for the entry at the specified date */
  public bool load_entry( ref DBEntry entry, bool create_if_not_found ) {

    Sqlite.Statement stmt;

    var query = "SELECT * FROM Entry WHERE date = '%s';".printf( entry.date );
    var err = _db.prepare_v2( query, query.length, out stmt );
    if( err != Sqlite.OK ) {
      return( false );
    }

    if( stmt.step() == Sqlite.ROW ) {
      entry.title = stmt.column_text( 1 );
      entry.text  = stmt.column_text( 2 );
      return( true );
    } else if( create_if_not_found ) {
      return( create_entry( ref entry ) );
    }

    return( false );

  }

  /* Saves the entry to the database */
  public bool save_entry( DBEntry entry ) {

    var query = """
      UPDATE Entry
      SET title = '%s', txt = '%s'
      WHERE date = '%s';
      """.printf( entry.title.replace("'", "''"), entry.text.replace("'", "''"), entry.date );

    string errmsg;
    var err = _db.exec( query, null, out errmsg );
    if( err != Sqlite.OK ) {
      stdout.printf( "err: %d, errmsg: %s\n", err, errmsg );
      return( false );
    }

    return( true );

  }

}
