 /*
* Copyright (c) 2018 (https://github.com/phase1geo/Journaler)
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
using GLib;
using Gee;

public class Journaler : Gtk.Application {

  private const string INTERFACE_SCHEMA = "org.gnome.desktop.interface";

  private static bool show_version = false;

  public  static GLib.Settings settings;
  public  static string version = "1.0";

  private MainWindow appwin;

  public Journaler () {

    Object( application_id: "com.github.phase1geo.journaler", flags: ApplicationFlags.HANDLES_OPEN );

    /* Register with the session manager so that we can be alerted to screensaver status */
    register_session = true;

    Intl.setlocale( LocaleCategory.ALL, "" );
    Intl.bindtextdomain( GETTEXT_PACKAGE, LOCALEDIR );
    Intl.bind_textdomain_codeset( GETTEXT_PACKAGE, "UTF-8" );
    Intl.textdomain( GETTEXT_PACKAGE );

    startup.connect( start_application );
    activate.connect( on_activate );

  }

  /* First method called in the startup process */
  private void start_application() {

    /* Initialize the settings */
    settings = new GLib.Settings( "com.github.phase1geo.journaler" );

    /* Add the application-specific icons */
    weak IconTheme default_theme = IconTheme.get_for_display( Display.get_default() );
    default_theme.add_resource_path( "/com/github/phase1geo/journaler" );

    /* Make sure that the user data directory exists */
    var dir = GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "db" );
    DirUtils.create_with_parents( dir, 0755 );

    /* Create the main window */
    appwin = new MainWindow( this, settings );

    var granite_settings = Granite.Settings.get_default();
    var gtk_settings = Gtk.Settings.get_default();

    /* Handle dark mode changes */
    gtk_settings.gtk_application_prefer_dark_theme = (
      granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK
    );
    appwin.themes.dark_mode = gtk_settings.gtk_application_prefer_dark_theme;

    granite_settings.notify["prefers-color-scheme"].connect (() => {
      gtk_settings.gtk_application_prefer_dark_theme = (
        granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK
      );
      appwin.themes.dark_mode = gtk_settings.gtk_application_prefer_dark_theme;
    });

    /* Handle any changes to the position of the window */
    /* DONT_KNOW_HOW_TO_HANDLE_YET
    appwin.configure_event.connect(() => {
      int root_x, root_y;
      int size_w, size_h;
      appwin.get_position( out root_x, out root_y );
      appwin.get_size( out size_w, out size_h );
      settings.set_int( "window-x", root_x );
      settings.set_int( "window-y", root_y );
      settings.set_int( "window-w", size_w );
      settings.set_int( "window-h", size_h );
      return( false );
    });
    */

  }

  /* Called if we have no files to open */
  private void on_activate() {
  }

  /* Parse the command-line arguments */
  private void parse_arguments( ref unowned string[] args ) {

    var context = new OptionContext( "- Journaler Options" );
    var options = new OptionEntry[2];

    /* Create the command-line options */
    options[0] = {"version", 0, 0, OptionArg.NONE, ref show_version, _( "Display version number" ), null};
    options[1] = {null};

    /* Parse the arguments */
    try {
      context.set_help_enabled( true );
      context.add_main_entries( options, null );
      context.parse( ref args );
    } catch( OptionError e ) {
      stdout.printf( _( "ERROR: %s\n" ), e.message );
      stdout.printf( _( "Run '%s --help' to see valid options\n" ), args[0] );
      Process.exit( 1 );
    }

    /* If the version was specified, output it and then exit */
    if( show_version ) {
      stdout.printf( version + "\n" );
      Process.exit( 0 );
    }

  }

  /* Main routine which gets everything started */
  public static int main( string[] args ) {

    var app = new Journaler();
    app.parse_arguments( ref args );

    return( app.run( args ) );

  }

}

