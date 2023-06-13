public class Journal {

  private string    _name        = "";
  private string    _description = "";
  private Database? _db          = null;

  public string name {
    get {
      return( _name );
    }
    set {
      if( _name != value ) {
        var old_db = db_path();
        var new_db = db_path( value );
        if( rename_db( old_db, new_db ) ) {
          _name = value;
          _db   = new Database( db_path() );
        }
      }
    }
  }
  public string description {
    get {
      return( _description );
    }
    set {
      if( _description != value ) {
        _description = value;
      }
    }
  }
  public Database? db {
    get {
      return( _db );
    }
  }

  /* Default constructor */
  public Journal( string name, string description ) {
    _name        = name;
    _description = description;
    _db          = new Database( db_path() );
  }

  /* Constructor */
  public Journal.from_xml( Xml.Node* node ) {
    load( node );
  }

  /* Gets the pathname of the associated database */
  private string db_path( string? n = null ) {
    var name = (n ?? _name).down().replace( " ", "-" );
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "db", name + ".db" ) );
  }

  /* Renames the database */
  private bool rename_db( string old_db, string new_db ) {
    return( FileUtils.rename( old_db, new_db ) == 0 );
  }

  /* Saves this journal in XML format */
  public Xml.Node* save() {

    Xml.Node* node = new Xml.Node( null, "journal" );

    node->set_prop( "name", _name );
    node->set_prop( "description", _description );

    return( node );

  }

  /* Loads the journal from XML format */
  public void load( Xml.Node* node ) {

    var n = node->get_prop( "name" );
    if( n != null ) {
      _name = n;
      _db   = new Database( db_path() );
    }

    var d = node->get_prop( "description" );
    if( d != null ) {
      _description = d;
    }

  }

}
