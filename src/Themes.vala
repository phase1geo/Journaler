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

public class Theme {

  public string name  { get; set; default = ""; }
  public string light { get; set; default = ""; }
  public string dark  { get; set; default = ""; }

  /* Default constructor */
  public Theme( string theme ) {
    var theme_bits = theme.split( "-" );
    name = theme_bits[0].splice( 0, 1, theme_bits[0].slice( 0, 1 ).up() );
    if( theme_bits.length == 2 ) {
      if( theme_bits[1] == "dark" ) {
        dark = theme;
      } else {
        light = theme;
      }
    } else {
      light = theme;
    }
  }

  /* Returns true if this theme matches the given theme.  If it matches, the value is stored */
  public bool matches( Theme theme ) {
    if( theme.name == name ) {
      if( dark != "" ) {
        light = theme.light;
      } else if( theme.dark != "" ) {
        dark = theme.dark;
      } else {
        dark  = light;
        light = theme.light;
      }
      return( true );
    }
    return( false );
  }

  /* We will purge this theme if it does not contain a dark and a light variant */
  public bool purge() {
    return( (light == "") || (dark == "") );
  }

  /* Returns the theme to use based on the dark mode setting */
  public string get_theme( bool dark_mode ) {
    return( dark_mode ? dark : light );
  }

  /* Returns the theme in a string for debug purposes */
  public string to_string() {
    return( "name: %s, light: %s, dark: %s".printf( name, light, dark ) ); 
  }

}

public class Themes {

  private Array<Theme> _themes;
  private bool         _dark_mode = false;
  private string       _current_theme;

  public Array<Theme> themes {
    get {
      return( _themes );
    }
  }
  public bool dark_mode {
    get {
      return( _dark_mode );
    }
    set {
      _dark_mode = value;
      theme_changed( get_current_theme() );
    }
  }
  public string theme {
    get {
      return( _current_theme );
    }
    set {
      if( _current_theme != value ) {
        _current_theme = value;
        theme_changed( get_current_theme() );
      }
    }
  }

  public signal void theme_changed( string name );

  /* Default constructor */
  public Themes() {

    _themes = new Array<Theme>();

    var style_mgr = GtkSource.StyleSchemeManager.get_default();

    foreach( var scheme in style_mgr.get_scheme_ids() ) {
      store( scheme );
    }

    purge();

    /* Let's setup the current theme */
    _current_theme = Journaler.settings.get_string( "default-theme" );
    if( get_theme_from_name( _current_theme ) == null ) {
      _current_theme = index( 0 ).name;
    }

  }

  /* Stores the given theme into the list of themes based on its dark/light setting */
  private void store( string name ) {
    var ttheme = new Theme( name );
    for( int i=0; i<_themes.length; i++ ) {
      if( _themes.index( i ).matches( ttheme ) ) {
        return;
      }
    }
    _themes.append_val( ttheme );
  }

  /* Remove all of the stored themes that do not have light/dark variants */
  private void purge() {
    for( int i=(int)(_themes.length - 1); i>=0; i-- ) {
      if( _themes.index( i ).purge() ) {
        _themes.remove_index( i );
      }
    }
  }

  /* Returns the number of stored themes */
  public int size() {
    return( (int)_themes.length );
  }

  /* Returns the theme at the given index */
  public Theme index( int idx ) {
    return( _themes.index( idx ) );
  }

  /* Returns the theme with the given name */
  public Theme? get_theme_from_name( string name ) {
    for( int i=0; i<_themes.length; i++ ) {
      if( _themes.index( i ).name == name ) {
        return( _themes.index( i ) );
      }
    }
    return( null );
  }

  /* Returns the gtksource.view theme name to use based on the current dark mode and settings default theme */
  private string get_current_theme() {
    var theme = get_theme_from_name( _current_theme );
    return( theme.get_theme( _dark_mode ) );
  }

}
