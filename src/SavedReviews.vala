public class SavedReviews {

  private Array<SavedReview> _reviews;

  /* Constructor */
  public SavedReviews() {
    _reviews = new Array<SavedReview>();
  }

  /* Adds a new saved review to this list */
  public void add_review( SavedReview review ) {
    _reviews.append_val( review );
    save();
  }

  /* Removes the review from the list */
  public void remove_review( int index ) {
    _reviews.remove_index( index );
    save();
  }

  /* Returns the number of stored reviews */
  public int size() {
    return( (int)_reviews.length );
  }

  /* Returns the review at the given index */
  public SavedReview get_review( int index ) {
    return( _reviews.index( index ) );
  }

  /* Returns the pathname of the XML file */
  private string xml_file() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "reviews.xml" ) );
  }

  /* Saves the reviews in XML format */
  public void save() {

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "reviews" );

    root->set_prop( "version", Journaler.version );

    for( int i=0; i<_reviews.length; i++ ) {
      root->add_child( _reviews.index( i ).save() );
    }

    doc->set_root_element( root );
    doc->save_format_file( xml_file(), 1 );

    delete doc;

  }

  /* Loads the reviews from XML format */
  public void load() {

    Xml.Doc* doc = Xml.Parser.read_file( xml_file(), null, (Xml.ParserOption.HUGE | Xml.ParserOption.NOWARNING) );
    if( doc == null ) {
      return;
    }

    Xml.Node* root = doc->get_root_element();

    var verson = root->get_prop( "version" );
    if( verson != null ) {
      check_version( verson );
    }

    for( Xml.Node* it = doc->get_root_element()->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "review") ) {
        var review = new SavedReview.from_xml( it );
        _reviews.append_val( review );
      }
    }

    delete doc;

  }

  /* Allows us to handle any version issues in the future, if needed */
  private void check_version( string version ) {

  }

}
