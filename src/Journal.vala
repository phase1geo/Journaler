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

public class Journal {

  private string    _name        = "";
  private bool      _hidden      = false;
  private string    _template    = "";
  private string    _description = "";
  private Database? _db          = null;
  private int       _next_id     = 1;

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
          _db   = new Database( db_path(), false );
        }
      }
    }
  }
  public string template {
    get {
      return( _template );
    }
    set {
      _template = value;
    }
  }
  public bool hidden {
    get {
      return( _hidden );
    }
    set {
      _hidden = value;
    }
  }
  public string description {
    get {
      return( _description );
    }
    set {
      _description = value;
    }
  }
  public Database? db {
    get {
      return( _db );
    }
  }
  public bool is_trash {
    get {
      return( _db.include_journal );
    }
  }

  public signal void save_needed();

  /* Default constructor */
  public Journal( string name, string template, string description ) {

    _name = name;
    make_directories();

    _template    = template;
    _description = description;
    _db          = new Database( db_path(), false );

  }

  /* Constructor for trash */
  public Journal.trash() {

    _name = _( "Trash" );
    make_directories();

    _db = new Database( db_path(), true );

  }

  /* Make the database and image directories */
  private void make_directories() {
    Utils.create_dir( journal_path() );
    Utils.create_dir( image_path() );
  }

  /* Constructor */
  public Journal.from_xml( Xml.Node* node, out bool loaded ) {
    loaded = load( node );
  }

  /* Returns the pathname of the journal database and images directory */
  private string journal_path( string? n = null ) {
    var name = (n ?? _name).down().replace( " ", "-" );
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "journals", name ) );
  }

  /* Gets the pathname of the associated database */
  private string db_path( string? name = null ) {
    return( GLib.Path.build_filename( journal_path( name ), "entries.db" ) );
  }

  /* Returns the pathname for the image directory */
  public string image_path( string? name = null ) {
    return( GLib.Path.build_filename( journal_path( name ), "images" ) );
  }

  /* Returns a new image file pathname */
  public int new_image_id() {
    var id = _next_id++;
    save_needed();
    return( id );
  }

  /* Renames the database */
  private bool rename_db( string old_db, string new_db ) {
    return( FileUtils.rename( old_db, new_db ) == 0 );
  }

  /* This should be called when we are deleting this journal entry */
  public bool remove_db() {
    return( FileUtils.unlink( db_path() ) == 0 );
  }

  /* Moves the given entry from this journal to the given to_journal, merging if necessary */
  public bool move_entry( DBEntry entry, Journal to_journal, string? to_date = null, string? to_time = null ) {

    var journal_move     = (this != to_journal);
    var create_entry     = new DBEntry.copy( entry );
    create_entry.journal = to_journal.name;
    create_entry.date    = to_date ?? entry.date;
    create_entry.time    = to_time ?? entry.time;

    if( journal_move ) {
      create_entry.copy_images( this, to_journal );
    }

    if( to_journal.db.create_entry( create_entry ) && to_journal.db.save_entry( this, create_entry ) ) {
      if( journal_move ) {
        foreach( var image in entry.images ) {
          entry.remove_image( this, image );
        }
      }
      return( db.remove_entry( entry ) );
    }

    return( false );

  }

  /* Saves this journal in XML format */
  public Xml.Node* save() {

    Xml.Node* node = new Xml.Node( null, "journal" );

    node->set_prop( "name", _name );
    node->set_prop( "template", _template );
    node->set_prop( "description", _description );
    node->set_prop( "next-id", _next_id.to_string() );
    node->set_prop( "hidden", hidden.to_string() );

    return( node );

  }

  /* Loads the journal from XML format */
  public bool load( Xml.Node* node ) {

    var n = node->get_prop( "name" );
    if( n != null ) {
      _name = n;
    }

    var t = node->get_prop( "template" );
    if( t != null ) {
      _template = t;
    }

    var d = node->get_prop( "description" );
    if( d != null ) {
      _description = d;
    }

    var i = node->get_prop( "next-id" );
    if( i != null ) {
      _next_id = int.parse( i );
    }

    var h = node->get_prop( "hidden" );
    if( h != null ) {
      hidden = bool.parse( h );
    }

    /* If the name was set and the database file exists, create the database */
    if( (_name != "") && FileUtils.test( db_path(), FileTest.EXISTS ) ) {
      _db = new Database( db_path(), false );
      return( true );
    }

    return( false );

  }

}
