public enum DBLoadResult {
  FAILED,
  LOADED,
  CREATED
}

public class DBEntry {

  private List<string> _tags = new List<string>();

  public string       title { get; set; default = ""; }
  public string       text  { get; set; default = ""; }
  public string       date  { get; set; default = ""; }
  public List<string> tags  {
    get {
      return( _tags );
    }
  }

  /* Default constructor */
  public DBEntry() {
    this.date = todays_date();
  }

  /* Constructor */
  public DBEntry.for_save( string title, string text, string tag_list ) {
    this.title = title;
    this.text  = text;
    this.date  = todays_date();
    store_tag_list( tag_list );
  }

  /* Constructor */
  public DBEntry.for_list( string title, string date ) {
    this.title = title;
    this.date  = date;
  }

  /* Constructor */
  public DBEntry.with_date( string title, string text, string tag_list, string date ) {
    this.title = title;
    this.text  = text;
    this.date  = date;
    store_tag_list( tag_list );
  }

  /* Returns true if the given tag currently exists */
  public bool contains_tag( string tag ) {
    return( !_tags.find( tag ).is_empty() );
  }

  /* Adds the given tag (if it doesn't already exist in the list) */
  public void add_tag( string tag ) {
    if( !contains_tag( tag ) ) {
      stdout.printf( "Does not contain tag (%s)\n", get_tag_list() );
      _tags.append( tag );
    }
  }

  /* Removes the given tag (if it exists in the list) */
  public void remove_tag( string tag ) {
    if( contains_tag( tag ) ) {
      _tags.remove( tag );
    }
  }

  /* Returns the tag list in the form suitable for display */
  public string get_tag_list() {
    string[] tag_array = {};
    foreach( string tag in _tags ) {
      tag_array += tag;
    }
    return( string.joinv( ", ", tag_array ) );
  }

  /* Stores the given comma-separated list as a list of tag strings */
  private void store_tag_list( string tag_list ) {
    var tag_array = tag_list.split( "," );
    foreach( string tag in tag_array ) {
      add_tag( tag.strip() );
    }
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

  /* Returns the DateTime version of the date */
  public DateTime datetime() {
    var dt = new DateTime.local( get_year(), get_month(), (int)get_day(), 0, 0, 0 );
    return( dt );
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

  /* Debug purposes.  Displays the contents of this entry */
  public string to_string() {
    string[] tag_array = {};
    foreach( string tag in tags ) {
      tag_array += tag;
    }
    return( "title: %s, text: %s, date: %s, tags: %s".printf( title, text, date, string.join( ":", tag_array ) ) );
  }

}

public class Database {

  private Sqlite.Database? _db = null;

  /* Default constructor */
  public Database( string db_file ) {

    // Open the database
    var err = Sqlite.Database.open( db_file, out _db );
    if( err != Sqlite.OK ) {
      stderr.printf( "ERROR:  Unable to open database: %s\n", _db.errmsg() );
      return;
    }

    // Make sure that no one else can read or write this file
    FileUtils.chmod( db_file, 0600 );

    // Make sure that the needed tables exist
    if( !create_tables() ) {
      stdout.printf( "ERROR:  Creating database tables\n" );
      return;
    }

    show_table( "Entry" );
    show_table( "Tag" );
    show_table( "TagMap" );

  }

  /* Creates the database tables if they do not already exist */
  private bool create_tables() {

    // Create the table if it doesn't already exist
    var entry_query = """
      CREATE TABLE IF NOT EXISTS Entry (
        id    INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
        title TEXT                              NOT NULL,
        txt   TEXT                              NOT NULL,
        date  TEXT                              NOT NULL
      );
      """;

    var tag_query = """
      CREATE TABLE IF NOT EXISTS Tag (
        id   INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
        name TEXT                              NOT NULL UNIQUE
      );
      """;

    var tag_map_query = """
      CREATE TABLE IF NOT EXISTS TagMap (
        id       INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
        entry_id INTEGER                           NOT NULL,
        tag_id   INTEGER                           NOT NULL
      );
      """;

    return( exec_query( entry_query ) &&
            exec_query( tag_query ) &&
            exec_query( tag_map_query ) );

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

    /* Insert the entry */
    var entry_query = """
      INSERT INTO Entry (title, txt, date) VALUES ('', '', '%s');
      """.printf( entry.date );

    if( !exec_query( entry_query ) ) {
      return( false );
    }

    var entry_id = (int)_db.last_insert_rowid();

    /* Add the tags and tag mappings */
    foreach( string tag in entry.tags ) {

      var tag_query = """
        INSERT INTO Tag (name) VALUES('%s');
        """.printf( tag );

      if( !exec_query( tag_query ) ) {
        return( false );
      }

      var tag_id = (int)_db.last_insert_rowid();

      var map_query = """
        INSERT INTO TagMap (entry_id, tag_id) VALUES (%d, %d);
        """.printf( entry_id, tag_id );

      if( !exec_query( map_query ) ) {
        return( false );
      }

    }

    return( true );

  }

  /* Retrieves the text for the entry at the specified date */
  public DBLoadResult load_entry( ref DBEntry entry, bool create_if_not_found ) {

    Sqlite.Statement stmt;

    var query = """
      SELECT
        Entry.*,
        Tag.name
      FROM
        Entry
        LEFT JOIN TagMap ON TagMap.entry_id = Entry.id
        LEFT JOIN Tag    ON TagMap.tag_id = Tag.id
      WHERE
        Entry.date = '%s'
      ORDER BY Entry.date;
    """.printf( entry.date );

    var err = _db.prepare_v2( query, query.length, out stmt );
    if( err != Sqlite.OK ) {
      stdout.printf( "Issue with prepare_v2, code: %d, msg: %s\n", _db.errcode(), _db.errmsg() );
      return( DBLoadResult.FAILED );
    }

    stdout.printf( "column_count: %d\n", stmt.column_count() );

    if( stmt.step() == Sqlite.ROW ) {
      while( stmt.step() == Sqlite.ROW ) {
        entry.title = stmt.column_text( 1 );
        entry.text  = stmt.column_text( 2 );
        var tag     = stmt.column_text( 4 );
        if( tag != null ) {
          stdout.printf( "appending tag: %s\n", tag );
          entry.add_tag( tag );
        }
      }
      return( DBLoadResult.LOADED );
    } else if( create_if_not_found && create_entry( ref entry ) ) {
      return( DBLoadResult.CREATED );
    }

    return( DBLoadResult.FAILED );

  }

  /* Saves the entry to the database */
  public bool save_entry( DBEntry entry ) {

    Sqlite.Statement stmt;

    var entry_query = """
      UPDATE Entry
      SET title = '%s', txt = '%s'
      WHERE date = '%s'
      RETURNING id;
      """.printf( entry.title.replace("'", "''"), entry.text.replace("'", "''"), entry.date );

    var err = _db.prepare_v2( entry_query, entry_query.length, out stmt );
    if( err != Sqlite.OK ) {
      stdout.printf( "Issue with prepare_v2, code: %d, msg: %s\n", _db.errcode(), _db.errmsg() );
      return( false );
    }

    stdout.printf( "column_count: %d\n", stmt.column_count() );

    /* Get the updated entry ID */
    var entry_id = -1;
    if( stmt.step() == Sqlite.ROW ) {
      entry_id = stmt.column_int( 0 );
    } else {
      return( false );
    }

    /* Let's store the tags and tag mappings */
    foreach( string tag in entry.tags ) {

      var tag_query = """
        INSERT INTO Tag (name) VALUES('%s');
        """.printf( tag );

      // Don't fail if there is an error (it may be because the tag already exists)
      exec_query( tag_query );

      var tag_id = (int)_db.last_insert_rowid();

      var map_query = """
        INSERT INTO TagMap (entry_id, tag_id) VALUES(%d, %d);
        """.printf( entry_id, tag_id );

      if( !exec_query( map_query ) ) {
        return( false );
      }

    }

    return( true );

  }

  /* Executes the given query on the database */
  private bool exec_query( string query ) {

    string errmsg;
    var err = _db.exec( query, null, out errmsg );
    if( err != Sqlite.OK ) {
      stdout.printf( "err: %d, errmsg: %s\n", err, errmsg );
      return( false );
    }

    return( true );

  }

  /* Displays the contents of the given table (loosely formatted) */
  private void show_table( string table_name ) {

    var query = """
      SELECT * FROM %s;
      """.printf( table_name );

    string errmsg;
    string[] res;
    int nrows, ncols;

    var err = _db.get_table( query, out res, out nrows, out ncols, out errmsg );
    if( err != Sqlite.OK ) {
      stdout.printf( "Issue with get_table, msg: %s\n", errmsg );
      return;
    }

    stdout.printf( "Table %s (rows: %d)\n", table_name, ((nrows == 0) ? 0 : (nrows - 1)) );
    stdout.printf( "--------------------------\n" );
    for( int i=0; i<nrows; i++ ) {
      for( int j=0; j<ncols; j++ ) {
        stdout.printf( "%s\t", res[(i * ncols) + j] );
      }
      stdout.printf( "\n" );
      if( i == 0 ) {
        stdout.printf( "--------------------------\n" );
      }
    }

    stdout.printf( "\n" );

  }

}
