using Gtk;
using Gdk;

public enum DBLoadResult {
  FAILED,
  LOADED,
  CREATED
}

public enum ChangeState {
  NONE,
  NEW,
  CHANGED,
  DELETED,
  NUM
}

public class DBImage {

  public int         id          { get; private set; default = -1; }
  public string      uri         { get; private set; default = ""; }
  public string      extension   { get; private set; default = ""; }
  public string      description { get; set; default = ""; }
  public ChangeState state       { get; set; default = ChangeState.NONE; }

  /* Default constructor */
  public DBImage() {}

  /* Constructor */
  public DBImage.from_database( int id, string uri, string extension, string description ) {
    this.id          = id;
    this.uri         = uri;
    this.extension   = extension;
    this.description = description;
  }

  /* Returns the image path */
  public string image_path( Journal journal ) {
    return( Path.build_filename( journal.image_path(), "image-%06d.%s".printf( id, extension ) ) );
  }

  /* Copies the file from the given URI to the local images directory */
  public bool store_file( Journal journal, string uri ) {

    var pre_state = ChangeState.CHANGED;

    if( id == -1 ) {
      id = journal.new_image_id();
      pre_state = ChangeState.NEW;
    }

    var parts = uri.split( "." );
    extension = parts[parts.length - 1];

    var ofile = File.new_for_uri( uri );
    var nfile = File.new_for_path( image_path( journal ) );

    try {
      if( ofile.copy( nfile, FileCopyFlags.OVERWRITE ) ) {
        this.state = pre_state;
        this.uri   = uri;
        return( true );
      }
    } catch( Error e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }

    return( false );

  }

  /* Removes the stored file from the file system */
  public bool remove_file( Journal journal ) {
    if( (id != -1) && (FileUtils.unlink( image_path( journal ) ) == 0) ) {
      state = ChangeState.DELETED;
      return( true );
    }
    return( false );
  }

  /*
   Generates a pixbuf from the stored image file such that the height of the image matches the specified height while
   retaining the original image proportions.
  */
  public Pixbuf? make_pixbuf( Journal journal, int height ) {
    try {
      var pixbuf = new Pixbuf.from_file_at_scale( image_path( journal ), -1, height, true );
      return( pixbuf );
    } catch( Error e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }
    return( null );
  }

  /* Returns true if the given image matches this one */
  public bool matches( DBImage image ) {
    return( id == image.id );
  }

}

public class DBEntry {

  private List<string>  _tags   = new List<string>();
  private List<DBImage> _images = new List<DBImage>();

  public string        journal        { get; set; default = ""; }
  public bool          trash          { get; set; default = false; }
  public string        title          { get; set; default = ""; }
  public string        text           { get; set; default = ""; }
  public string        date           { get; set; default = ""; }
  public string        time           { get; set; default = ""; }
  public bool          images_changed { get; set; default = false; }
  public bool          loaded         { get; set; default = false; }

  public List<string> tags  {
    get {
      return( _tags );
    }
  }
  public List<DBImage> images {
    get {
      return( _images );
    }
  }

  /* Default constructor */
  public DBEntry() {
    this.date = todays_date();
    this.time = todays_time();
  }

  /* Constructor */
  public DBEntry.for_save( string journal, string title, string text, string tag_list ) {
    this.journal = journal;
    this.title   = title;
    this.text    = text;
    this.date    = todays_date();
    store_tag_list( tag_list );
  }

  /* Constructor */
  public DBEntry.for_list( string journal, bool trash, string title, string date ) {
    this.journal = journal;
    this.trash   = trash;
    this.title   = title;
    this.date    = date;
  }

  /* Constructor */
  public DBEntry.with_date( string journal, string title, string text, string tag_list, string date, string time ) {
    this.journal = journal;
    this.title   = title;
    this.text    = text;
    this.date    = date;
    this.time    = time;
    store_tag_list( tag_list );
  }

  /* Merges an entry into this one */
  public void merge_with_entry( DBEntry entry ) {

    /* If the text does not match, append the text of the entry to the end of our text, placing a horizontal separator line */
    if( text != entry.text ) {
      if( text == "" ) {
        text = entry.text;
      } else if( entry.text != "" ) {
        text += "\n\n---\n\n%s".printf( entry.text );
      }
    }

    /* If this entry doesn't contain an image but the other one does, use the other entry's image data */
    foreach( var image in entry.images ) {
      _images.append( image );
      images_changed = true;
    }

    /* Let's merge the tags */
    foreach( var tag in entry._tags ) {
      if( !contains_tag( tag ) ) {
        add_tag( tag );
      }
    }

  }

  /*
   Adds the given image.  If the image add works properly, we will return the new pathname of the file;
   otherwise, we will return null.
  */
  public void add_new_image( Journal journal, string uri ) {
    var image = new DBImage();
    if( image.store_file( journal, uri ) ) {
      _images.append( image );
    }
  }

  /* Adds the given existing image to the entry list */
  public void add_image( DBImage image ) {
    _images.append( image );
  }

  /* Removes the given image */
  public void remove_image( Journal journal, DBImage image ) {
    if( image.remove_file( journal ) ) {
      _images.remove( image );
    }
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

  /* Returns the title of this entry */
  public string gen_title() {
    return( (this.title == "") ?
            Utils.build_entry_title( Journaler.settings.get_string( "entry-title-prefix" ),
                                     Journaler.settings.get_string( "entry-title-suffix" ), this.date ) :
            this.title );
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

  /* Returns the day in DateTime form */
  public uint get_day() {
    var date_bits = date.split( "-" );
    return( (uint)int.parse( date_bits[2] ) );
  }

  /* Returns the stored hour */
  public int get_hour() {
    if( time == "" ) {
      return( 0 );
    } else {
      var time_bits = time.split( ":" );
      return( int.parse( time_bits[0] ) );
    }
  }

  /* Returns the stored minute */
  public int get_minute() {
    if( time == "" ) {
      return( 0 );
    } else {
      var time_bits = time.split( ":" );
      return( int.parse( time_bits[1] ) );
    }
  }

  /* Returns the string version of today's date */
  public static string yesterdays_date() {
    var today = new DateTime.now_local();
    var yesterday = today.add_days( -1 );
    return( datetime_date( yesterday ) );
  }

  /* Returns the string version of today's date */
  public static string todays_date() {
    var today = new DateTime.now_local();
    return( datetime_date( today ) );
  }

  /* Returns the string version of the current time */
  public static string todays_time() {
    var today = new DateTime.now_local();
    return( datetime_time( today ) );
  }

  /* Returns the DateTime version of the date */
  public DateTime datetime() {
    var dt = new DateTime.local( get_year(), get_month(), (int)get_day(), get_hour(), get_minute(), 0 );
    return( dt );
  }

  /* Returns the string date for the given DateTime object */
  public static string datetime_date( DateTime dt ) {
    return( "%04d-%02d-%02d".printf( dt.get_year(), dt.get_month(), dt.get_day_of_month() ) );
  }

  /* Returns the string time for the given DateTime object */
  public static string datetime_time( DateTime dt ) {
    return( "%02d:%02d".printf( dt.get_hour(), dt.get_minute() ) );
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
    return( "journal: %s, title: %s, text: %s, date: %s, tags: %s".printf( journal, title, text, date, string.joinv( ":", tag_array ) ) );
  }

}

public class Database {

  private enum EntryPos {
    ID = 0,
    TITLE,
    TEXT,
    DATE,
    TIME,
    JOURNAL_ID,
    JOURNAL,
    TAG
  }

  private const int ERRCODE_NOT_UNIQUE = 19;

  private Sqlite.Database? _db = null;
  private bool             _include_journal = false;

  /* Useful for debugging database issues by displaying the table contents */
  private bool debug = false;

  public bool include_journal {
    get {
      return( _include_journal );
    }
  }

  /* Default constructor */
  public Database( string db_file, bool include_journal ) {

    _include_journal = include_journal;

    // Open the database
    var err = Sqlite.Database.open( db_file, out _db );
    if( err != Sqlite.OK ) {
      stderr.printf( "ERROR:  Unable to open database %s: %s\n", db_file, _db.errmsg() );
      return;
    }

    // Make sure that no one else can read or write this file
    FileUtils.chmod( db_file, 0600 );

    // Make sure that the needed tables exist
    if( !create_tables() ) {
      stdout.printf( "ERROR:  Creating database tables\n" );
      return;
    }

    show_all_tables( "After database creation" );

  }

  /* Creates a string that is suitable for SQL operations */
  private string sql_string( string str ) {
    return( str.replace( "'", "''" ) );
  }

  /* Creates the database tables if they do not already exist */
  private bool create_tables() {

    var journal_query = """
      CREATE TABLE IF NOT EXISTS Journal (
        id          INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
        name        TEXT                              NUT NULL UNIQUE,
        template    TEXT,
        description TEXT
      );
      """;

    // Create the table if it doesn't already exist
    var entry_query = """
      CREATE TABLE IF NOT EXISTS Entry (
        id         INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
        title      TEXT                              NOT NULL,
        txt        TEXT                              NOT NULL,
        date       TEXT                              NOT NULL,
        time       TEXT                              NOT NULL,
        journal_id INTEGER                           NOT NULL
      );
      """;

    var image_query = """
      CREATE TABLE IF NOT EXISTS Image (
        id          INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
        file_id     INTEGER                           NOT NULL,
        uri         TEXT                              NOT NULL,
        extension   TEXT                              NOT NULL,
        description TEXT,
        entry_id    INTEGER                           NOT NULL
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

    return( exec_query( journal_query ) &&
            exec_query( entry_query ) &&
            exec_query( image_query ) &&
            exec_query( tag_query ) &&
            exec_query( tag_map_query ) );

  }

  /* Returns the list of all entries to be displayed in the listbox */
  public bool get_all_entries( bool trash, Array<DBEntry> entries ) {

    var query = """
      SELECT
        Entry.*,
        Journal.name 
      FROM
        Entry
        LEFT JOIN Journal ON Journal.id = Entry.journal_id
      ORDER BY Entry.date DESC;
      """;

    var retval = exec_query( query, (ncols, vals, names) => {
      var entry = new DBEntry.for_list( vals[EntryPos.JOURNAL], trash, vals[EntryPos.TITLE], vals[EntryPos.DATE] );
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

  /* Returns the list of all stored images that currently exist */
  public bool get_all_images( Array<DBImage> images ) {

    var query = "SELECT * FROM Image;";

    var retval = exec_query( query, (ncols, vals, names) => {
      var image = new DBImage.from_database( int.parse( vals[1] ), vals[2], vals[3], vals[4] );
      images.append_val( image );
      return( 0 );
    });

    return( retval );

  }

  /* Creates a new entry with the given date if one could not be found */
  public bool create_entry( DBEntry entry ) {

    var journal_select = "SELECT id FROM Journal WHERE name = '%s';".printf( entry.journal );
    var journal_id     = -1;
    var res = exec_query( journal_select, (ncols, vals, names) => {
      journal_id = int.parse( vals[0] );
      return( 0 );
    });

    if( journal_id == -1 ) {

      var journal_insert = """
        INSERT INTO Journal (name, template, description)
        VALUES('%s', '', '')
        RETURNING id;
        """.printf( sql_string( entry.journal ) );

      res = exec_query( journal_insert, (ncols, vals, names) => {
        journal_id = int.parse( vals[0] );
        return( 0 );
      });

    }

    assert( journal_id != -1 );

    /* Insert the entry */
    var entry_query = """
        INSERT INTO Entry (title, txt, date, time, journal_id)
        VALUES ('', '%s', '%s', '%s', %d);
        """.printf( sql_string( entry.text ), entry.date, entry.time, journal_id );

    if( !exec_query( entry_query ) ) {
      return( false );
    }

    /* Indicate that this entry has data from the database */
    entry.loaded = true;

    show_all_tables( "After entry creation\n" );

    return( true );

  }

  /* Performs search query using tags, date and search string */
  public bool query_entries( bool trash, List<string> tags, string? start_date, string? end_date, string str,
                             Gee.List<DBEntry> matched_entries ) {

    string[] where = {};

    if( (start_date != null) || (end_date != null) ) { 
      string[] where_date = {};
      if( start_date != null ) {
        where_date += "(Entry.date >= '%s')".printf( start_date );
      }
      if( end_date != null ) {
        where_date += "(Entry.date <= '%s')".printf( end_date );
      }
      if( where_date.length == 1 ) {
        where += where_date[0];
      } else {
        where += "(%s)".printf( string.joinv( " AND ", where_date ) );
      }
    }

    var untagged = false;
    if( (tags.length() > 0) && (tags.nth_data( 0 ) == _( "Untagged" )) ) {
      untagged = true;
    }

    if( str != "" ) {
      where += "((Entry.title LIKE '%%%s%%') OR (Entry.txt LIKE '%%%s%%'))".printf( str, str );
    }

    var query = """
      SELECT
        Entry.*,
        Journal.name,
        Tag.name
      FROM
        Entry
        LEFT JOIN Journal ON Journal.id = Entry.journal_id
        LEFT JOIN TagMap  ON TagMap.entry_id = Entry.id
        LEFT JOIN Tag     ON TagMap.tag_id = Tag.id
      %s
      ORDER BY Entry.date;
    """.printf( (where.length == 0) ? "" : "WHERE %s".printf( string.joinv( " AND ", where ) ) );

    var last_id = "";
    var retval = exec_query( query, (ncols, vals, names) => {
      var tag = vals[EntryPos.TAG];
      if( (vals[EntryPos.ID] != last_id) && ((tag == null) ? untagged : (tags.find(tag) != null)) ) {
        var entry = new DBEntry.for_list( vals[EntryPos.JOURNAL], trash, vals[EntryPos.TITLE], vals[EntryPos.DATE] );
        matched_entries.add( entry );
        last_id = vals[EntryPos.ID];
      }
      return( 0 );
    });

    return( retval );

  }

  /* Retrieves the text for the entry at the specified date */
  public DBLoadResult load_entry( DBEntry entry, bool create_if_not_found ) {

    var entry_id = -1;

    var entry_query = """
      SELECT
        Entry.*
      FROM
        Entry
        LEFT JOIN Journal ON Journal.id = Entry.journal_id
      WHERE
        Entry.date = '%s' AND Journal.name = '%s'
      ORDER BY Entry.date;
    """.printf( entry.date, sql_string( entry.journal ) );

    exec_query( entry_query, (ncols, vals, names) => {
      entry.loaded = true;
      entry_id     = int.parse( vals[EntryPos.ID] );
      entry.title  = vals[EntryPos.TITLE];
      entry.text   = vals[EntryPos.TEXT];
      entry.time   = vals[EntryPos.TIME];
      return( 0 );
    });

    if( entry_id != -1 ) {

      /* Load images */
      var image_query = "SELECT * FROM Image WHERE entry_id = %d;".printf( entry_id );
      exec_query( image_query, (ncols, vals, names) => {
        var image = new DBImage.from_database( int.parse( vals[1] ), vals[2], vals[3], vals[4] );
        entry.add_image( image );
        return( 0 );
      });

      /* Load tags */
      var tag_query = """
        SELECT
          Tag.name
        FROM
          Entry
        LEFT JOIN TagMap ON TagMap.entry_id = Entry.id
        LEFT JOIN Tag    ON TagMap.tag_id = Tag.id
        WHERE Entry.id = %d;
        """.printf( entry_id );
      exec_query( tag_query, (ncols, vals, names) => {
        if( vals[0] != null ) {
          entry.add_tag( vals[0] );
        }
        return( 0 );
      });

    }

    if( entry.loaded ) {
      return( DBLoadResult.LOADED );
    } else if( create_if_not_found && create_entry( entry ) ) {
      return( DBLoadResult.CREATED );
    }

    return( DBLoadResult.FAILED );

  }

  /* Saves only the tags stored in this entry in the Tag table */
  public bool save_tags_only( DBEntry entry ) {

    foreach( var tag in entry.tags ) {
      var tag_query = "INSERT INTO Tag (name) VALUES('%s');".printf( sql_string( tag ) );
      exec_query( tag_query );
    }

    return( true );

  }

  /* Save any changes to the given journal data */
  public bool save_journal( string orig_name, string name, string template, string description ) {

    var query = """
      UPDATE Journal
      SET name = '%s', template = '%s', description = '%s'
      WHERE name = '%s';
      """.printf( sql_string( name ), sql_string( template ), sql_string( description ), sql_string( orig_name ) );

    var res = exec_query( query );

    show_all_tables( "After journal save" );

    return( res );

  }

  /* Loads the journal information for the Journal with the given name */
  public bool load_journal( string name, out string template, out string description ) {

    var query = "SELECT * FROM Journal WHERE name = '%s';".printf( sql_string( name ) );

    var rd_template = "";
    var rd_description = "";

    var res = exec_query( query, (ncols, vals, names) => {
      rd_template    = vals[1];
      rd_description = vals[2];
      return( 0 );
    });

    template = rd_template;
    description = rd_description;

    return( res );

  }

  /* Saves the entry to the database */
  public bool save_entry( Journal journal, DBEntry entry ) {

    var entry_query = """ 
      UPDATE Entry
      SET title = '%s', txt = '%s'
      WHERE date = '%s'
      RETURNING id;
      """.printf( sql_string( entry.title ), sql_string( entry.text ), entry.date );

    var entry_id = -1;
    var res = exec_query( entry_query, (ncols, vals, names) => {
      entry_id = int.parse( vals[EntryPos.ID] );
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

    /* Handle associated images */
    foreach( var image in entry.images ) {
      var image_query = "";
      switch( image.state ) {
        case ChangeState.NEW :
          image_query = """
            INSERT INTO Image (file_id, uri, extension, description, entry_id)
            VALUES(%d, '%s', '%s', '%s', %d);
          """.printf( image.id, image.uri, image.extension, sql_string( image.description ), entry_id );
          break;
        case ChangeState.CHANGED :
          image_query = """
            UPDATE Image
            SET uri = '%s' extension = '%s', description = '%s'
            WHERE file_id = %d;
          """.printf( image.uri, image.extension, sql_string( image.description ), image.id );
          break;
        case ChangeState.DELETED :
          image_query = """
            DELETE FROM Image
            WHERE file_id = %d";
          """.printf( image.id );
          break;
        default :  break;
      }
      if( (image_query != "") && exec_query( image_query ) ) {
        if( image.state == ChangeState.DELETED ) {
          entry.remove_image( journal, image );
        } else {
          image.state = ChangeState.NONE;
        }
      }
    }

    show_all_tables( "After save" );

    return( true );

  }

  /* Removes the entry that matches the given entry  */
  public bool remove_entry( DBEntry entry ) {

    var entry_query = "DELETE FROM Entry WHERE date = '%s' RETURNING id;".printf( entry.date );

    var entry_id = -1;
    var res = exec_query( entry_query, (ncols, vals, names) => {
      entry_id = int.parse( vals[EntryPos.ID] );
      return( 0 );
    });

    if( entry_id != -1 ) {

      var map_query = "DELETE FROM TagMap WHERE entry_id = %d;".printf( entry_id );
      exec_query( map_query );

      var image_query = "DELETE FROM Image WHERE entry_id = %d;".printf( entry_id );
      exec_query( image_query );

    }

    show_all_tables( "After entry removed" );

    return( res );

  }

  /* Removes all entries that contain empty text strings.  This may only be useful for debugging. */
  public bool purge_empty_entries() {

    var entry_query = "DELETE FROM Entry WHERE txt = '' RETURNING id;";

    int[] entry_ids = {};
    var res = exec_query( entry_query, (ncols, vals, names) => {
      entry_ids += int.parse( vals[EntryPos.ID] );
      return( 0 );
    });

    foreach( var entry_id in entry_ids ) {

      var map_query = "DELETE FROM TagMap WHERE entry_id = %d;".printf( entry_id );
      exec_query( map_query );

      var image_query = "DELETE FROM Image WHERE entry_id = %d;".printf( entry_id );
      exec_query( image_query );

    }

    show_all_tables( "After entry purging" );

    return( res );

  }

  /* Executes the given query on the database */
  private bool exec_query( string query, Sqlite.Callback? callback = null ) {

    string errmsg;
    var err = _db.exec( query, callback, out errmsg );
    if( err != Sqlite.OK ) {
      if( err != ERRCODE_NOT_UNIQUE ) {
        stdout.printf( "query: %s, err: %d, errmsg: %s\n", query, err, errmsg );
      }
      return( false );
    }

    return( true );

  }

  /* Displays the contents of the given table (loosely formatted) */
  public void show_table( string table_name ) {

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
    if( !debug ) return;
    stdout.printf( "%s\n", msg );
    stdout.printf( "==========================\n" );
    show_table( "Journal" );
    show_table( "Entry" );
    show_table( "Tag" );
    show_table( "TagMap" );
    show_table( "Image" );
  }

}
