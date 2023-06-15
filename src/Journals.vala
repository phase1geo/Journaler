public class Journals {

  private Array<Journal> _journals;
  private Journal        _current;

  public Journal current {
    get {
      return( _current );
    }
  }

  public signal void current_changed();

  /* Default constructor */
  public Journals() {
    _journals = new Array<Journal>();
    load();
    if( _journals.length == 0 ) {
      _current = new Journal( "Journal", "" );
      add_journal( _current );
    } else {
      _current = _journals.index( 0 );
    }
    current_changed();
  }

  /* Adds the given journal to the list of journals */
  public void add_journal( Journal journal ) {
    _journals.append_val( journal );
    _current = journal;
    save();
    current_changed();
  }

  /* Sets the current journal to the given one */
  public void set_current( int index ) {
    _current = get_journal( index );
    current_changed();
  }

  /* Removes the current journal entry */
  public void remove_journal( Journal journal ) {
    for( int i=0; i<_journals.length; i++ ) {
      if( (_journals.index( i ) == journal) && (_journals.length > 1) ) {
        if( _current == journal ) {
          _current = get_journal( ((i + 1) == _journals.length) ? (i - 1) : i );
          current_changed();
        }
        _journals.remove_index( i );
        save();
      }
    }
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

  /* Returns the pathname of the journals.xml file */
  private string xml_file() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "journals.xml" ) );
  }

  /* Saves the journals in XML format */
  public void save() {

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "journals" );

    for( int i=0; i<_journals.length; i++ ) {
      root->add_child( _journals.index( i ).save() );
    }

    doc->set_root_element( root );
    doc->save_format_file( xml_file(), 1 );

    delete doc;

  }

  /* Loads the journals from the XML file */
  public void load() {

    Xml.Doc* doc = Xml.Parser.read_file( xml_file(), null, (Xml.ParserOption.HUGE | Xml.ParserOption.NOWARNING) );
    if( doc == null ) {
      return;
    }

    for( Xml.Node* it = doc->get_root_element()->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "journal") ) {
        var journal = new Journal.from_xml( it );
        _journals.append_val( journal );
      }
    }

    delete doc;

  }

}
