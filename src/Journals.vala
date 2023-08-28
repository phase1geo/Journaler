public class Journals {

  private Array<Journal> _journals;
  private Journal        _trash;
  private Journal        _current;

  public Journal current {
    get {
      return( _current );
    }
    set {
      if( _current != value ) {
        _current = value;
        current_changed( false );
        save();
      }
    }
  }
  public Journal trash {
    get {
      return( _trash );
    }
  }

  public signal void current_changed( bool refresh );
  public signal void list_changed();

  /* Default constructor */
  public Journals( Templates templates ) {

    _journals = new Array<Journal>();
    _trash    = new Journal.trash();

    templates.changed.connect((name, added) => {
      if( !added ) {
        remove_template_from_journals( name );
      }
    });

  }

  /* Adds the given journal to the list of journals */
  public void add_journal( Journal journal, bool fast = false ) {
    journal.save_needed.connect( save );
    _journals.append_val( journal );
    if( !fast ) {
      current = journal;
      list_changed();
    } else {
      list_changed();
      save();
    }
  }

  /* Adds a default journal called "Journal" where there are no journals */
  private void add_default_journal() {
    var journal = new Journal( _( "Journal" ), "", "" );
    add_journal( journal );
  }

  /* Removes the current journal entry */
  public void remove_journal( Journal journal ) {
    for( int i=0; i<_journals.length; i++ ) {
      if( _journals.index( i ) == journal ) {
        _journals.index( i ).save_needed.disconnect( save );
        _journals.index( i ).remove_db();
        _journals.remove_index( i );
        if( _journals.length == 0 ) {
          add_default_journal();
        } else {
          if( _current == journal ) {
            current = get_journal( (i == _journals.length) ? (i - 1) : i );
          } else {
            save();
          }
          list_changed();
        }
        break;
      }
    }
  }

  /* Empties the trash */
  public bool empty_trash() {
    if( _trash.remove_db() ) {
      _trash = new Journal.trash();
      current_changed( true );
      return( true );
    }
    return( false );
  }

  /* Returns the number of stored journals */
  public int num_journals() {
    return( (int)_journals.length );
  }

  /* Retrieves the journal at the given index */
  public Journal get_journal( int index ) {
    return( _journals.index( index ) );
  }

  /* Retrieves the journal with the given name */
  public Journal? get_journal_by_name( string name ) {
    for( int i=0; i<_journals.length; i++ ) {
      if( _journals.index( i ).name == name ) {
        return( _journals.index( i ) );
      }
    }
    return( null );
  }

  /* Returns true if at least one journal is using the given template */
  public bool does_journal_use_template( string template ) {
    for( int i=0; i<_journals.length; i++ ) {
      if( get_journal( i ).template == template ) {
        return( true );
      }
    }
    return( false );
  }

  /* Removes the template from any journals that use it be default */
  private void remove_template_from_journals( string template ) {
    for( int i=0; i<_journals.length; i++ ) {
      if( get_journal( i ).template == template ) {
        get_journal( i ).template = "";
      }
    }
  }

  /* Purges all of the empty journal entries */
  public bool purge_empty_entries() {

    var res = true;

    for( int i=0; i<_journals.length; i++ ) {
      var journal = _journals.index( i );
      res &= journal.db.purge_empty_entries();
    }

    if( res ) {
      current_changed( true );
    }

    return( res );

  }

  /* Returns the pathname of the journals.xml file */
  private string xml_file() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "journals.xml" ) );
  }

  /* Saves the journals in XML format */
  public void save() {

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "journals" );
    var       current_index = 0;

    root->set_prop( "version", Journaler.version );

    for( int i=0; i<_journals.length; i++ ) {
      if( _journals.index( i ) == _current ) {
        current_index = i;
      }
      root->add_child( _journals.index( i ).save() );
    }

    root->set_prop( "current", current_index.to_string() );

    doc->set_root_element( root );
    doc->save_format_file( xml_file(), 1 );

    delete doc;

  }

  /* Loads the journals from the XML file */
  public void load() {

    Xml.Doc* doc = Xml.Parser.read_file( xml_file(), null, (Xml.ParserOption.HUGE | Xml.ParserOption.NOWARNING) );
    if( doc == null ) {
      add_default_journal();
      return;
    }

    Xml.Node* root = doc->get_root_element();

    var v = root->get_prop( "version" );
    if( v != null ) {
      check_version( v );
    }

    var c = root->get_prop( "current" );
    var current_index = 0;
    if( c != null ) {
      current_index = int.parse( c );
    }

    for( Xml.Node* it = doc->get_root_element()->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "journal") ) {
        bool loaded = false;
        var journal = new Journal.from_xml( it, out loaded );
        if( loaded ) {
          journal.save_needed.connect( save );
          _journals.append_val( journal );
        }
      }
    }

    delete doc;

    /* Set the current journal */
    if( _journals.length == 0 ) {
      add_default_journal();
    } else {
      _current = _journals.index( current_index );
    }

    current_changed( false );
    list_changed();

  }

  /*
   Allows us to check that the version will be compatible with the current version and
   perform any updates to make it compatible.
  */
  private void check_version( string version ) {

    // TBD

  }

}
