/*
* Copyright (c) 2023-2026 (https://github.com/phase1geo/Journaler)
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

using Gtk;
using Gdk;
using GLib;
using Gee;

public class Journaler : Gtk.Application {

  private const string INTERFACE_SCHEMA = "org.gnome.desktop.interface";
  public  const string static_version = "1.2.0";

  private static bool show_version = false;

  public  static GLib.Settings settings;

  private MainWindow appwin;

  public Journaler () {

    Object(
      application_id: "io.github.phase1geo.journaler",
      flags: ApplicationFlags.HANDLES_OPEN,
      version: static_version
    );

    // Register with the session manager so that we can be alerted to screensaver status
    register_session = true;

    Intl.setlocale( LocaleCategory.ALL, "" );
    Intl.bindtextdomain( GETTEXT_PACKAGE, LOCALEDIR );
    Intl.bind_textdomain_codeset( GETTEXT_PACKAGE, "UTF-8" );
    Intl.textdomain( GETTEXT_PACKAGE );

    Environment.set_application_name( _( "Journaler" ) );

    startup.connect( start_application );
    activate.connect( on_activate );

  }

  //-------------------------------------------------------------
  // First method called in the startup process
  private void start_application() {

    // Initialize the settings
    settings = new GLib.Settings( "io.github.phase1geo.journaler" );

    // Add the application-specific icons
    weak IconTheme default_theme = IconTheme.get_for_display( Display.get_default() );
    default_theme.add_resource_path( "/io/github/phase1geo/journaler/images" );
    default_theme.add_resource_path( "/io/github/phase1geo/journaler/images/icons/hicolor" );

    // Make sure that the user data directory exists
    var app_dir = GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler" );
    Utils.create_dir( app_dir );

    // Create the main window
    appwin = new MainWindow( this, settings );

    var granite_settings = Granite.Settings.get_default();
    var gtk_settings = Gtk.Settings.get_default();

    // Handle dark mode changes
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

  }

  //-------------------------------------------------------------
  // Called if we have no files to open
  private void on_activate() {
  }

  //-------------------------------------------------------------
  // Parse the command-line arguments
  private void parse_arguments( ref unowned string[] args ) {

    var context = new OptionContext( "- Journaler Options" );
    var options = new OptionEntry[2];

    // Create the command-line options
    options[0] = {"version", 0, 0, OptionArg.NONE, ref show_version, _( "Display version number" ), null};
    options[1] = {null};

    // Parse the arguments
    try {
      context.set_help_enabled( true );
      context.add_main_entries( options, null );
      context.parse( ref args );
    } catch( OptionError e ) {
      stdout.printf( _( "ERROR: %s\n" ), e.message );
      stdout.printf( _( "Run '%s --help' to see valid options\n" ), args[0] );
      Process.exit( 1 );
    }

    // If the version was specified, output it and then exit
    if( show_version ) {
      stdout.printf( version + "\n" );
      Process.exit( 0 );
    }

  }

  //-------------------------------------------------------------
  // Main routine which gets everything started
  public static int main( string[] args ) {

    var app = new Journaler();
    app.parse_arguments( ref args );

    return( app.run( args ) );

  }

}

