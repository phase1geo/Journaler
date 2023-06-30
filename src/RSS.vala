public class RSS {

  private string _items = "";

  public string items {
    get {
      return( _items );
    }
  }

  /* Default constructor */
  public RSS( string str ) {

    parse_rss( str );

  }

  void parse_rss( string str ) {

    Xml.Doc* doc = Xml.Parser.parse_memory( str, str.length );
    if( doc == null ) {
      return;
    }

    for( Xml.Node* it = doc->get_root_element()->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "channel") ) {
        _items = parse_channel( it );
        break;
      }
    }

    delete doc;

  }

  private string parse_channel( Xml.Node* node ) {
    string[] items = {};
    for( Xml.Node* it = node->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "item") ) {
        items += parse_item( it );
      }
    }
    return( string.joinv( "\n", items ) );
  }

  private string parse_item( Xml.Node* node ) {
    var title = "";
    var link  = "";
    for( Xml.Node* it = node->children; it != null; it = it->next ) {
      if( it->type == Xml.ElementType.ELEMENT_NODE ) {
        switch( it->name ) {
          case "title" :  title = parse_title( it );  break;
          case "link"  :  link  = parse_link( it );   break;
        }
      }
    }
    if( (title != "") && (link != "") ) {
      return( "- [%s](%s)".printf( title, link ) );
    }
    return( "" );
  }

  private string parse_title( Xml.Node* node ) {
    return( node->get_content() );
  }

  private string parse_link( Xml.Node* node ) {
    return( node->get_content() );
  }

}
