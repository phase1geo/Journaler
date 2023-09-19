/*
* Copyright (c) 2023 (https://github.com/phase1geo/Journaler)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Trevor Williams <phase1geo@gmail.com>
*/

public class RSS {

  private string _items = "";

  public string items {
    get {
      return( _items );
    }
  }

  /* Default constructor */
  public RSS( string str, int max_items ) {

    parse_rss( str, max_items );

  }

  void parse_rss( string str, int max_items ) {

    Xml.Doc* doc = Xml.Parser.parse_memory( str, str.length );
    if( doc == null ) {
      return;
    }

    for( Xml.Node* it = doc->get_root_element()->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "channel") ) {
        _items = parse_channel( it, max_items );
        break;
      }
    }

    delete doc;

  }

  private string parse_channel( Xml.Node* node, int max_items ) {
    string[] items = {};
    for( Xml.Node* it = node->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "item") ) {
        items += parse_item( it );
      }
    }
    return( string.joinv( "\n", items[0:max_items] ) );
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
