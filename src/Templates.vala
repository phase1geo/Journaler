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

public class Templates {

  private List<Template> _templates;
  private TemplateVars   _template_vars;

  public List<Template> templates {
    get {
      return( _templates );
    }
  }
  public TemplateVars template_vars {
    get {
      return( _template_vars );
    }
  }

  public signal void changed( string name, bool added );

  /* Default constructor */
  public Templates() {
    
    _templates     = new List<Template>();
    _template_vars = new TemplateVars();

  }

  /* Returns the directory containing the templates.snippets file */
  private string xml_dir() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "snippets" ) );
  }

  /* Returns the pathname of the templates.snippets file */
  private string xml_file() {
    return( GLib.Path.build_filename( xml_dir(), "templates.snippets" ) );
  }

  /* Adds the given template and sorts the result */
  public void add_template( Template template ) {

    if( find_by_name( template.name ) == null ) {
      _templates.append( template );
      _templates.sort((a, b) => {
        return( strcmp( a.name, b.name ) );
      });
    }

    save();
    changed( template.name, true );

  }

  /* Removes the given template based on its name */
  public bool remove_template( string name ) {

    var template = find_by_name( name );
    if( template != null ) {
      _templates.remove( template );
      save();
      changed( name, false );
      return( true );
    }

    return( false );

  }

  /* Returns the template associated with the given name.  If was not found, returns null */
  public Template? find_by_name( string name ) {

    foreach( var template in _templates ) {
      if( template.name == name ) {
        return( template );
      }
    }

    return( null );

  }

  /* Returns the snippet associated with the given template name */
  public GtkSource.Snippet? get_snippet( string name ) {

    var mgr = GtkSource.SnippetManager.get_default();
    var search_path = mgr.search_path;
    search_path += xml_dir();
    mgr.search_path = search_path;

    var snippet = mgr.get_snippet( "journaler-templates", null, Template.get_snippet_trigger( name ) );
    if( snippet != null ) {
      _template_vars.set_variables( snippet );
    }

    return( snippet );

  }

  /* Saves the current templates in XML format */
  public void save() {

    Utils.create_dir( xml_dir() );

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "snippets" );

    root->set_prop( "_group", "journaler-templates" );

    foreach( var template in _templates ) {
      root->add_child( template.save( doc ) );
    }

    doc->set_root_element( root );
    doc->save_format_file( xml_file(), 1 );

    delete doc;

  }

  /* Loads the available templates from XML format */
  public void load() {

    Xml.Doc* doc = Xml.Parser.read_file( xml_file(), null, (Xml.ParserOption.HUGE | Xml.ParserOption.NOWARNING) );
    if( doc == null ) {
      return;
    }

    for( Xml.Node* it = doc->get_root_element()->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "snippet") ) {
        var loaded   = false;
        var template = new Template.from_xml( it, out loaded );
        if( loaded ) {
          _templates.append( template );
        }
      }
    }

    delete doc;

    if( _templates.length() > 0 ) {
      changed( "", false );
    }

  }

}
