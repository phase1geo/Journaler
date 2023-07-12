using Gtk;

public class LockerImage {

  private static int _id = 1;

  private string _name;
  private string _css_syntax;
  private bool   _built_in = false;

  public bool built_in {
    get {
      return( _built_in );
    }
  }

  /* Default constructor */
  public LockerImage( bool built_in, string css_syntax ) {
    _name       = "custom-%04d".printf( _id++ );
    _css_syntax = css_syntax;
    _built_in   = built_in;
  }

  /* Constructor */
  public LockerImage.linear_gradient( bool built_in, string[] colors ) {
    _name       = "line-grad-%04d".printf( _id++ );
    _css_syntax = "linear-gradient(%s)".printf( string.joinv( ",", colors ) );
    _built_in   = built_in;
  }

  /* Constructor */
  public LockerImage.url( bool built_in, string url ) {
    _name       = "url-%04d".printf( _id++ );
    _css_syntax = "url(\"%s\")".printf( url );
    _built_in   = built_in;
  }

  /* Constructor */
  public LockerImage.from_xml( Xml.Node* node ) {
    load( node );
  }

  /* Returns the CSS class for this image */
  public string css_class() {
    return( "login-pane-%s".printf( _name ) );
  }

  /* Returns the CSS required to generate login pane background image */
  public string get_css() {
    return( ".%s { background-image: %s; background-position: center; background-size: 100%; background-repeat: no-repeat; }\n".printf( css_class(), _css_syntax ) );
  }

  /* Saves the contents of this image as XML */
  public Xml.Node* save() {

    Xml.Node* node = new Xml.Node( null, "image" );

    node->set_prop( "name", _name );
    node->set_prop( "css", _css_syntax );
    
    return( node );

  }

  /* Loads the contents of this image from XML */
  public void load( Xml.Node* node ) {

    var n = node->get_prop( "name" );
    if( n != null ) {
      _name = n;
    }

    var c = node->get_prop( "css" );
    if( c != null ) {
      _css_syntax = c;
    }

  }

}

public class Locker {

  private MainWindow         _win;
  private Array<LockerImage> _images;
  private Array<Widget>      _widgets;
  private int                _current = 0;

  public int current {
    get {
      return( _current );
    }
    set {
      if( _current != value ) {
        update_widgets( _current, value );
        _current = value;
        save();
      }
    }
  }

  /* Default constructor */
  public Locker( MainWindow win ) {

    _win     = win;
    _images  = new Array<LockerImage>();
    _widgets = new Array<Widget>();

    /* Add built-in images */
    add_image( new LockerImage.linear_gradient( true, {"lightblue", "pink"} ) );
    add_image( new LockerImage.linear_gradient( true, {"purple", "darkgreen"} ) );
    add_image( new LockerImage.linear_gradient( true, {"#E95420", "#000"} ) );
    add_image( new LockerImage.linear_gradient( true, {"#92B662", "#000"} ) );
    add_image( new LockerImage.linear_gradient( true, {"#666666", "#000"} ) );

    add_image( new LockerImage.url( true, "https://raw.githubusercontent.com/elementary/brand/master/logomark.svg" ) );
    add_image( new LockerImage( true, "url(\"https://raw.githubusercontent.com/elementary/brand/master/logomark.svg\"), linear-gradient(#666, #000)" ) );

    /* Load the XML data */
    load();

    /* Update the CSS provider */
    update_css();

  }

  /* Adds an image for a given set of colors */
  public void add_linear_gradient_image( string[] colors ) {
    add_image( new LockerImage.linear_gradient( false, colors ) );
  }

  /* Adds an image for a given URI */
  public void add_uri_image( string uri ) {
    add_image( new LockerImage.url( false, uri ) );
  }

  /* Adds the specified image to the stored list */
  private void add_image( LockerImage image ) {
    _images.append_val( image );
  }

  /* Removes the given image from the list */
  public void remove_image( int idx ) {
    _images.remove_index( idx );
    save();
  }

  /* Adds the widget that displays the lock screen image */
  public void add_widget( Widget w ) {
    w.add_css_class( css_class( current ) );
    _widgets.append_val( w );
  }

  /* Returns the number of stored background images */
  public int size() {
    return( (int)_images.length );
  }

  /* Returns the locker image at the specified index in the array */
  public string css_class( int idx ) {
    return( _images.index( idx ).css_class() );
  }

  /* Returns true if this image is a built-in image */
  public bool is_built_in( int idx ) {
    return( _images.index( idx ).built_in );
  }

  /* Updates the CSS */
  private void update_css() {

    var css = "";

    for( int i=0; i<_images.length; i++ ) {
      css += _images.index( i ).get_css();
    }

    var provider = new CssProvider();
    provider.load_from_data( css.data );
    StyleContext.add_provider_for_display( _win.get_display(), provider, STYLE_PROVIDER_PRIORITY_APPLICATION );

  }

  /* Updates the widget CSS classes */
  private void update_widgets( int prev_index, int curr_index ) {
    for( int i=0; i<_widgets.length; i++ ) {
      _widgets.index( i ).remove_css_class( css_class( prev_index ) );
      _widgets.index( i ).add_css_class( css_class( curr_index ) );
    }
  }

  /* Returns the pathname of the XML file */
  public string xml_file() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "locker.xml" ) );
  }

  /* Saves the contents of this class as XML */
  public void save() {

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "images" );

    root->set_prop( "version", Journaler.version );
    root->set_prop( "current", current.to_string() );

    for( int i=0; i<_images.length; i++ ) {
      if( !_images.index( i ).built_in ) {
        root->add_child( _images.index( i ).save() );
      }
    }

    doc->set_root_element( root );
    doc->save_format_file( xml_file(), 1 );

    delete doc;

  }

  /* Load the contents of the locker XML file into memory */
  public void load() {

    Xml.Doc* doc = Xml.Parser.read_file( xml_file(), null, (Xml.ParserOption.HUGE | Xml.ParserOption.NOWARNING) );
    if( doc == null ) {
      return;
    }

    Xml.Node* root = doc->get_root_element();

    var version = root->get_prop( "version" );
    if( version != null ) {
      check_version( version );
    }

    var c = root->get_prop( "current" );
    if( c != null ) {
      _current = int.parse( c );
    }

    for( Xml.Node* it = doc->get_root_element()->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "image") ) {
        var image = new LockerImage.from_xml( it );
        _images.append_val( image );
      }
    }

    delete doc;

  }

  public void check_version( string version ) {

    // TBD

  }

}

