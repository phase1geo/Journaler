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

using GCrypt;

/*
 This implementation is based on https://www.gnupg.org/documentation/manuals/gcrypt.pdf

 For error codes, see: https://github.com/Chronic-Dev/libgpg-error/blob/master/doc/errorref.txt
*/
public class Crypt {

  private Cipher.Cipher _cipher = null;
  private uint8[]       _key;

  /* Default constructor */
  public Crypt() {

    /* Disable secure memory */
    var err = control( ControlCommand.DISABLE_SECMEM, 0 );
    if( err != 0 ) {
      stdout.printf( "control.DISABLE_SECMEM error: %s (%d)\n", err.to_string(), err.code() );
    }

    err = control( ControlCommand.SET_VERBOSITY, 10 );
    if( err != 0 ) {
      stdout.printf( "control.SET_VERBOSITY error: %s (%d)\n", err.to_string(), err.code() );
    }
    err = control( ControlCommand.DUMP_MEMORY_STATS, 0 );
    if( err != 0 ) {
      stdout.printf( "control.DUMP_MEMORY_STATS error: %s (%d)\n", err.to_string(), err.code() );
    }

    /* Specify that initialization has completed */
    control( ControlCommand.INITIALIZATION_FINISHED, 0 );

    /* Create the cipher */
    err = Cipher.Cipher.open( out _cipher, Cipher.Algorithm.AES128, Cipher.Mode.CBC, /* Cipher.Mode.AESWRAP,*/ 0 );
    if( err != 0 ) {
      stdout.printf( "Cipher.open error: %s\n", err.to_string() );
    }

  }

  /* Closes the associated cipher (this should be called on application exit) */
  public void close() {
    if( _cipher != null ) {
      _cipher.close();
    }
  }

  /* Sets the key based on the given password */
  public void generate_key( string password ) {

    if( _cipher == null ) {
      return;
    }

    var salt  = "abcdefgh";  // TBD
    var iters = (ulong)100;

    _key = new uint8[16];

    /* Generate the key */
    var err = KeyDerivation.derive( password.data, KeyDerivation.Algorithm.ITERSALTED_S2K, Hash.Algorithm.SHA256, salt.data, iters, _key );
    if( err != 0 ) {
      stdout.printf( "KeyDerivation.derive error: %s, %s\n", err.to_string(), err.source_to_string() );
    }

  }

  /* Resets the cipher with the key */
  private void reset() {

    /* Reset the cipher */
    var err = _cipher.reset();
    if( err != 0 ) {
      stdout.printf( "Cipher.reset: %s\n", err.to_string() );
    }

    /* Set the key */
    err = _cipher.set_key( (uchar[])_key );
    if( err != 0 ) {
      stdout.printf( "Cipher.set_key error: %s\n", err.to_string() );
    }

    /* Set the key */
    err = _cipher.set_iv( (uchar[])_key[0:16] );
    if( err != 0 ) {
      stdout.printf( "Cipher.set_iv error: %s\n", err.to_string() );
    }

  }

  /* Encrypts the given string and generates base64 output */
  public string encrypt( string str ) {

    if( _cipher == null ) {
      return( str );
    }

    reset();

    var uchars = str.length + (16 - (str.length % 16));

    uchar[] out_buffer = new uchar[uchars + 16];
    uchar[] in_buffer  = new uchar[uchars];

    for( int i=0; i<str.length; i++ ) {
      in_buffer[i] = (uchar)str.data[i];
    }

    var err = _cipher.encrypt( out_buffer, in_buffer );
    if( err != 0 ) {
      stdout.printf( "cipher.encrypt: %s (%d)\n", err.to_string(), err.code() );
    }

    return( Base64.encode( out_buffer ) );

  }

  /* Takes base64 input string and decrypts it to a normal string */
  public string decrypt( string str ) {

    if( _cipher == null ) {
      return( str );
    }

    reset();

    var decoded_str = Base64.decode( str );

    var uchars = decoded_str.length + (16 - (decoded_str.length % 16));

    uchar[] out_buffer = new uchar[uchars];
    uchar[] in_buffer  = new uchar[uchars];

    for( int i=0; i<decoded_str.length; i++ ) {
      in_buffer[i] = (uchar)decoded_str[i];
    }

    var err = _cipher.decrypt( out_buffer, in_buffer );
    if( err != 0 ) {
      stdout.printf( "cipher.decrypt: %s (%d)\n", err.to_string(), err.code() );
    }

    return( (string)out_buffer );

  }

}
