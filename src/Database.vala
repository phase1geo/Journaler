using Gtk;

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
  public Image?       image { get; set; default = null; }
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
  public DBEntry.with_date( string title, string text, Image? image, string tag_list, string date ) {
    this.title = title;
    this.text  = text;
    this.date  = date;
    this.image = image;
    store_tag_list( tag_list );
  }

  /* Returns true if the given tag currently exists */
  public bool contains_tag( string tag ) {
    return( !_tags.find( tag ).is_empty() );
  }

  /* Adds the given tag (if it doesn't already exist in the list) */
  public void add_tag( string tag ) {
    if( !contains_tag( tag ) ) {
      _tags.append( tag );
    }
  }

  /* Replaces the old tag with the new tag */
  public void replace_tag( string old_tag, string new_tag ) {
    var index = _tags.index( old_tag );
    if( index != -1 ) {
      _tags.remove( old_tag );
      _tags.insert( new_tag, index );
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

  /* Sets the image with the given byte array data */
  /*
  public void set_image_byte_array( byte[] barray ) {
  }

  public byte[] get_image_byte_array() {
    var outputStream = new ByteArrayOutputStream();
    bitmap.compress(CompressFormat.PNG, 0, outputStream);
    return( outputStream.toByteArray() );
  }
  */

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
    return( "title: %s, text: %s, date: %s, tags: %s".printf( title, text, date, string.joinv( ":", tag_array ) ) );
  }

}

public class Database {

  private const int ERRCODE_NOT_UNIQUE = 19;

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

    // show_all_tables( "After database creation" );

  }

  /* Creates the database tables if they do not already exist */
  private bool create_tables() {

    // Create the table if it doesn't already exist
    var entry_query = """
      CREATE TABLE IF NOT EXISTS Entry (
        id    INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
        title TEXT                              NOT NULL,
        txt   TEXT                              NOT NULL,
        date  TEXT                              NOT NULL,
        image BLOB
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
        entry_id INTEGER,
        tag_id   INTEGER,
        UNIQUE (entry_id, tag_id)
      );
      """;

    return( exec_query( entry_query ) &&
            exec_query( tag_query ) &&
            exec_query( tag_map_query ) );

  }

  /* Returns the list of all entries to be displayed in the listbox */
  public bool get_all_entries( Array<DBEntry> entries ) {

    var query = "SELECT * FROM Entry ORDER BY date DESC;";

    var retval = exec_query( query, (ncols, vals, names) => {
      var entry = new DBEntry.for_list( vals[1], vals[3] );
      entries.append_val( entry );
      return( 0 );
    });

    return( retval );

  }

  /* Returns the list of all tags that currently exist */
  public bool get_all_tags( Array<string> tags ) {

    var query = "SELECT * FROM Tag;";

    var retval = exec_query( query, (ncols, vals, names) => {
      tags.append_val( vals[1] );
      return( 0 );
    });

    return( retval );

  }

  /* Creates a new entry with the given date if one could not be found */
  private bool create_entry( DBEntry entry ) {

    /* Insert the entry */
    var entry_query = """
      INSERT INTO Entry (title, txt, date) VALUES ('', '', '%s');
      """.printf( entry.date );

    if( !exec_query( entry_query ) ) {
      return( false );
    }

    // show_all_tables( "After entry creation\n" );

    return( true );

  }

  /* Retrieves the text for the entry at the specified date */
  public DBLoadResult load_entry( DBEntry entry, bool create_if_not_found ) {

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

    var loaded = false;
    exec_query( query, (ncols, vals, names) => {
      entry.title = vals[1];
      entry.text  = vals[2];
      var tag = vals[5];
      if( tag != null ) {
        entry.add_tag( tag );
      }
      loaded = true;
      return( 0 );
    });

    if( loaded ) {
      return( DBLoadResult.LOADED );
    } else if( create_if_not_found && create_entry( entry ) ) {
      return( DBLoadResult.CREATED );
    }

    return( DBLoadResult.FAILED );

  }

  /* Saves only the tags stored in this entry in the Tag table */
  public bool save_tags_only( DBEntry entry ) {

    foreach( var tag in entry.tags ) {
      var tag_query = "INSERT INTO Tag (name) VALUES('%s');".printf( tag );
      exec_query( tag_query );
    }

    return( true );

  }

  /* Saves the entry to the database */
  public bool save_entry( DBEntry entry ) {

    var entry_query = """
      UPDATE Entry
      SET title = '%s', txt = '%s'
      WHERE date = '%s'
      RETURNING id;
      """.printf( entry.title.replace("'", "''"), entry.text.replace("'", "''"), entry.date );

    var entry_id = -1;
    var res = exec_query( entry_query, (ncols, vals, names) => {
      entry_id = int.parse( vals[0] );
      return( 0 );
    });

    /* If the entry update failed something bad happened so stop here */
    if( !res || (entry_id == -1) ) {
      return( false );
    }

    /* Delete the tag-map entries associated with the updated entry */
    var map_del_query = "DELETE FROM TagMap WHERE entry_id = %d;".printf( entry_id );
    exec_query( map_del_query );

    /* Let's store the tags and tag mappings */
    foreach( string tag in entry.tags ) {

      /* Insert the tag into the table */
      var tag_query = "INSERT INTO Tag (name) VALUES('%s');".printf( tag );
      exec_query( tag_query );

      /* Get the index of the tag (even if it wasn't inserted */
      var tag2_query = "SELECT id FROM Tag WHERE name = '%s';".printf( tag );
      var tag_id     = -1;
      exec_query( tag2_query, (ncols, vals, names) => {
        tag_id = int.parse( vals[0] );
        return( 0 );
      });

      /* Add the tag-map entry */
      if( (entry_id != -1) && (tag_id != -1) ) {
        var map_query = "INSERT INTO TagMap (entry_id, tag_id) VALUES(%d, %d);".printf( entry_id, tag_id );
        exec_query( map_query );
      }

    }

    // show_all_tables( "After save" );

    return( true );

  }

  /* Executes the given query on the database */
  private bool exec_query( string query, Sqlite.Callback? callback = null ) {

    string errmsg;
    var err = _db.exec( query, callback, out errmsg );
    if( err != Sqlite.OK ) {
      if( err != ERRCODE_NOT_UNIQUE ) {
        stdout.printf( "err: %d, errmsg: %s\n", err, errmsg );
      }
      return( false );
    }

    return( true );

  }

  /* Displays the contents of the given table (loosely formatted) */
  private void show_table( string table_name ) {

    var query = """
      SELECT * FROM %s;
      """.printf( table_name );

    stdout.printf( "Table %s\n", table_name );
    stdout.printf( "--------------------------\n" );

    var i = 0;
    exec_query( query, (ncols, vals, names) => {
      if( i++ == 0 ) {
        for( int j=0; j<ncols; j++ ) {
          stdout.printf( "%s\t", names[j] );
        }
        stdout.printf( "\n--------------------------\n" );
      }
      for( int j=0; j<ncols; j++ ) {
        stdout.printf( "%s\t", vals[j] );
      }
      stdout.printf( "\n" );
      return( 0 );
    });

    stdout.printf( "\n" );

  }

  /* Displays all of the tables */
  private void show_all_tables( string msg ) {
    stdout.printf( "%s\n", msg );
    stdout.printf( "==========================\n" );
    show_table( "Entry" );
    show_table( "Tag" );
    show_table( "TagMap" );
  }

}
