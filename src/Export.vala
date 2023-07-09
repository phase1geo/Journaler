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

using Gtk;
using Gdk;
using Gee;

public class Export {

  private HashMap<string,Widget> _settings;
  private string                 _directory;
  private static int             _image_id = 1;

  public string   name       { get; private set; }
  public string   label      { get; private set; }
  public string[] extensions { get; private set; }
  public bool     importable { get; private set; }
  public bool     exportable { get; private set; }

  public bool include_images { get; set; default = false; }

  /* Constructor */
  public Export( string name, string label, string[] extensions, bool exportable, bool importable ) {
    _settings = new HashMap<string,Widget>();
    this.name       = name;
    this.label      = label;
    this.extensions = extensions;
    this.exportable = exportable;
    this.importable = importable;
  }

  public signal void settings_changed();

  /* Exports the specified journals to a file or archive */
  public bool export( string fname, Array<Journal> journals ) {
    var format_name = "";
    return(
      initialize_export( fname, out format_name ) &&
      do_export( format_name, journals ) &&
      finalize_export( fname )
    );
  }

  public bool import( string fname, Journals journals, Journal? journal = null ) {
    var format_name = "";
    return(
      initialize_import( fname, out format_name ) &&
      do_import( format_name, journals, journal ) &&
      finalize_import( fname )
    );
  }

  /* Performs export to the given filename */
  protected virtual bool do_export( string fname, Array<Journal> journals ) {
    return( false );
  }

  /* Imports given filename into drawing area */
  protected virtual bool do_import( string fname, Journals journals, Journal? journal = null ) {
    return( false );
  }

  private bool initialize_export( string fname, out string format_name ) {

    format_name = include_images ? Path.build_filename( fname, fname.slice( 0, (fname.length - ".bundle".length) ) ) : fname;
    _directory  = include_images ? fname : Path.get_dirname( fname );
    _image_id   = 1;

    if( include_images ) {

      // If the directory already exists, remove it
      if( FileUtils.test( fname, FileTest.EXISTS ) && (DirUtils.remove( fname ) != 0) ) {
        return( false );
      }

      // Create the directories
      DirUtils.create_with_parents( Path.build_filename( fname, "images" ), 0700 );

    }

    return( true );

  }

  private bool finalize_export( string fname ) {

    return( true );

  }

  private bool initialize_import( string fname, out string format_name ) {

    var bundle  = ".bundle";
    format_name = fname.has_suffix( bundle ) ? Path.build_filename( fname, fname.slice( 0, (fname.length - bundle.length) ) ) : fname;
    _directory  = fname.has_suffix( bundle ) ? fname : Path.get_dirname( fname );

    return( true );

  }

  private bool finalize_import( string fname ) {

    return( true );

  }

  /* Creates an image file from the given pixbuf and returns the pathname */
  protected string? create_image( Pixbuf pixbuf ) {

    try {
      string fname = Path.build_filename( "images", "image-%06d.png".printf( _image_id++ ) );
      if( pixbuf.save( Path.build_filename( _directory, fname ), "png", "compression", "7" ) ) {
        return( fname );
      }
    } catch( Error e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }

    return( null );

  }

  public bool settings_available() {
    return( _settings.size > 0 );
  }

  /* Adds settings to the export dialog page */
  public virtual void add_settings( Grid grid ) {}

  private Label make_help( string help ) {

    var lbl = new Label( help ) {
      margin_start    = 10,
      margin_bottom   = 10,
      xalign          = (float)0,
      justify         = Justification.LEFT,
      max_width_chars = 40,
      wrap_mode       = Pango.WrapMode.WORD,
      wrap            = true
    };

    return( lbl );

  }

  protected void add_setting_bool( string name, Grid grid, string label, string? help, bool dflt ) {

    var row = _settings.size * 2;

    var lbl = new Label( Utils.make_title( label ) );
    lbl.halign     = Align.START;
    lbl.use_markup = true;

    var sw = new Switch() {
      halign  = Align.END,
      hexpand = true
    };
    sw.activate.connect(() => {
      sw.active = !sw.active;
      settings_changed();
    });

    grid.attach( lbl, 0, row );
    grid.attach( sw,  1, row );

    if( help != null ) {
      var hlp = make_help( help );
      grid.attach( hlp, 0, (row + 1) );
    }

    _settings.@set( name, sw );

  }

  protected void add_setting_scale( string name, Grid grid, string label, string? help, int min, int max, int step, int dflt ) {

    var row = _settings.size * 2;

    var lbl = new Label( Utils.make_title( label ) );
    lbl.halign     = Align.START;
    lbl.use_markup = true;

    var scale = new Scale.with_range( Orientation.HORIZONTAL, min, max, step ) {
      halign       = Align.END,
      hexpand      = true,
      draw_value   = true,
      round_digits = max.to_string().char_count(),
    };
    scale.value_changed.connect(() => {
      settings_changed();
    });
    scale.set_size_request( 150, -1 );

    grid.attach( lbl,   0, row );
    grid.attach( scale, 1, row );

    if( help != null ) {
      var hlp = make_help( help );
      grid.attach( hlp, 0, (row + 1) );
    }

    _settings.@set( name, scale );

  }

  /* Returns true if the given setting is a boolean */
  public bool is_bool_setting( string name ) {
    return( _settings.has_key( name ) && ((_settings.@get( name ) as Switch) != null) );
  }

  /* Returns true if the given setting is a scale */
  public bool is_scale_setting( string name ) {
    return( _settings.has_key( name ) && ((_settings.@get( name ) as Scale) != null) );
  }

  public void set_bool( string name, bool value ) {
    assert( _settings.has_key( name ) );
    var sw = (Switch)_settings.@get( name );
    sw.active = value;
  }

  protected bool get_bool( string name ) {
    assert( _settings.has_key( name ) );
    var sw = (Switch)_settings.@get( name );
    return( sw.active );
  }

  public void set_scale( string name, int value ) {
    assert( _settings.has_key( name ) );
    var scale = (Scale)_settings.@get( name );
    var double_value = (double)value;
    scale.set_value( double_value );
  }

  protected int get_scale( string name ) {
    assert( _settings.has_key( name ) );
    var scale = (Scale)_settings.@get( name );
    return( (int)scale.get_value() );
  }

  /* Saves the settings */
  public virtual void save_settings( Xml.Node* node ) {}

  /* Loads the settings */
  public virtual void load_settings( Xml.Node* node ) {}

  /* Returns true if the given filename is targetted for this export type */
  public bool filename_matches( string fname, out string basename ) {
    basename = "";
    foreach( string extension in extensions ) {
      if( fname.has_suffix( extension ) ) {
        basename = fname.slice( 0, (fname.length - extension.length) );
        return( true );
      }
    }
    return( false );
  }

  /* Saves the state of this export */
  public Xml.Node* save() {
    Xml.Node* node = new Xml.Node( null, "export" );
    node->set_prop( "name", name );
    save_settings( node );
    return( node );
  }

  /* Loads the state of this export */
  public void load( Xml.Node* node ) {
    load_settings( node );
  }

}


