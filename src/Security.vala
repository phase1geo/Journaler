public class Security {

  /* Gets the pathname of the password file */
  private static string get_password_file() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "security.txt" ) );
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
