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
using Gee;

public class ExportJSON : Export {

  /* Constructor */
  public ExportJSON() {
    base( "json", _( "JSON" ), {"json"}, true, false );
  }

  /* Performs export to the given filename */
  public override bool do_export( string fname, Array<Journal> journals ) {

    var builder = new Json.Builder();

    builder.begin_array();

    for( int i=0; i<journals.length; i++ ) {
      export_journal( builder, journals.index( i ) );
    }

    builder.end_array();

    var generator = new Json.Generator();
    generator.pretty = true;
    generator.set_root( builder.get_root() );

    try {
      return( generator.to_file( fname ) );
    } catch( Error e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }

    return( false );

  }

  /* Exports a journal in JSON format */
  private void export_journal( Json.Builder builder, Journal journal ) {

    builder.begin_object();

      builder.set_member_name( "journal" );

      builder.begin_object();

        builder.set_member_name( "name" );
        builder.add_string_value( journal.name );

        builder.set_member_name( "description" );
        builder.add_string_value( journal.description );

        var entries = new Array<DBEntry>();
        journal.db.get_all_entries( false, entries );

        builder.set_member_name( "entries" );
        builder.begin_array();

          for( int i=0; i<entries.length; i++ ) {
            export_entry( builder, journal, entries.index( i ) );
          }

        builder.end_array();

      builder.end_object();

    builder.end_object();

  }

  /* Exports an entry in JSON format */
  private void export_entry( Json.Builder builder, Journal journal, DBEntry entry ) {

    var load_entry = new DBEntry();
    load_entry.date = entry.date;

    var result = journal.db.load_entry( load_entry, false );
    if( result == DBLoadResult.LOADED ) {

      builder.begin_object();

        builder.set_member_name( "title" );
        builder.add_string_value( load_entry.title );

        builder.set_member_name( "date" );
        builder.add_string_value( load_entry.date );

        builder.set_member_name( "time" );
        builder.add_string_value( load_entry.time );

        builder.set_member_name( "tags" );
        builder.begin_array();

          foreach( var tag in load_entry.tags ) {
            builder.add_string_value( tag );
          }

        builder.end_array();

        if( (load_entry.images.length() > 0) && include_images ) {

          builder.set_member_name( "images" );
          builder.begin_array();

            foreach( var image in load_entry.images ) {
              var path = create_image( journal, image );
              if( path != null ) {
                builder.begin_object();
                  builder.set_member_name( "path" );
                  builder.add_string_value( path );
                  builder.set_member_name( "description" );
                  builder.add_string_value( image.description );
                builder.end_object();
              }
            }

          builder.end_array();

        }

        builder.set_member_name( "text" );
        builder.add_string_value( load_entry.text );

      builder.end_object();

    }

  }

}


