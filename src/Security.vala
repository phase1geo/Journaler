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

public class Security {

  /* Gets the pathname of the password file */
  private static string get_password_file() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "security" ) );
  }

  /* Returns true if the password has been previously set */
  public static bool does_password_exist() {
    return( FileUtils.test( get_password_file(), FileTest.EXISTS ) );
  } 

  /* Encrypts the given password */
  private static string encrypt_password( string password ) {
    var cipher = new Crypt();
    cipher.generate_key( password );
    var encrypted = cipher.encrypt( password );
    // cipher.close();
    return( encrypted );
  }

  /* Creates the password file, writing the given password in encrypted form */
  public static bool create_password_file( string password ) {
    if( !does_password_exist() ) {
      try {
        FileUtils.set_contents_full( get_password_file(), encrypt_password( password ), -1, 0, 0400 );
        return( true );
      } catch( FileError e ) {
        stderr.printf( "ERROR: %s\n", e.message );
      }
    }
    return( false );
  }

  /* Checks to see if the given password matches the stored password */
  public static bool does_password_match( string password ) {
    if( does_password_exist() ) {
      try {
        string str;
        FileUtils.get_contents( get_password_file(), out str );
        return( str == encrypt_password( password ) );
      } catch( FileError e ) {
        stderr.printf( "ERROR: %s\n", e.message );
      }
    }
    return( false );
  }

}
