/*
* Copyright (c) 2023 (https://github.com/phase1geo/Journaler)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
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

public class Template {

  public string name { get; set; default = _( "Template" ); }
  public string text { get; set; default = ""; }

  /* Default constructor */
  public Template( string name, string text ) {
    this.name = name;
    this.text = text;
  }

  /* Constructor */
  public Template.from_xml( Xml.Node* node, out bool loaded ) {
    loaded = load( node );
  }

  /* Returns the snippet trigger for this template */
  public static string get_snippet_trigger( string str ) {
    return( "%" + str.down().replace( " ", "-" ) + "%" );
  }

  /* Saves the template in XML format */
  public Xml.Node* save( Xml.Doc* doc ) {

    Xml.Node* node  = new Xml.Node( null, "snippet" );
    Xml.Node* tnode = new Xml.Node( null, "text" );

    node->set_prop( "_name", name );
    node->set_prop( "_description", "" );
    node->set_prop( "trigger", get_snippet_trigger( name ) );

    tnode->set_prop( "languages", "markdown" );
    tnode->add_child( doc->new_cdata_block( text, text.length ) );

    node->add_child( tnode );

    return( node );

  }

  /* Loads the template data from XML format */
  public bool load( Xml.Node* node ) {

    var loaded = false;

    var n = node->get_prop( "_name" );
    if( n != null ) {
      name   = n;
      loaded = true;
    }

    if( (node->children != null) && (node->children->type == Xml.ElementType.ELEMENT_NODE) ) {
      var tnode = node->children;
      if( (tnode->children != null) && (tnode->children->type == Xml.ElementType.CDATA_SECTION_NODE) ) {
        text = tnode->get_content();
      }
    }

    return( loaded );

  }

}
