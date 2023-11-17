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

public class TagList {

  private List<string> _tags;

  public delegate void ForeachFunc( string data );

  /* Constructor */
  public TagList() {
    clear();
  }

  /* Copy constructor */
  public void copy( TagList other ) {
    clear();
    foreach( var tag in other._tags ) {
      _tags.append( tag );
    }
  }

  /* Removes all of the tags from this taglist */
  public void clear() {
    _tags = new List<string>();
  }

  /* Returns true if the given tag currently exists */
  public bool contains_tag( string tag ) {
    return( _tags.find_custom( tag, strcmp ) != null );
  }

  /* Adds the given tag (if it doesn't already exist in the list) */
  public void add_tag( string tag ) {
    if( !contains_tag( tag ) ) {
      _tags.append( tag );
    }
  }

  /* Adds the contents of the specified taglist to our taglist, avoiding copies */
  public void add_tag_list( TagList tags ) {
    tags.foreach((tag) => {
      if( !contains_tag( tag ) ) {
        _tags.append( tag );
      }
    });
  }

  /* Adds the contents of the specified string list, avoiding copies */
  public void add_string_list( List<string> tags ) {
    foreach( var tag in tags ) {
      if( (tag != null) && !contains_tag( tag ) ) {
        _tags.append( tag );
      }
    }
  }

  /* Replaces the old tag with the new tag */
  public void replace_tag( string old_tag, string new_tag ) {
    var index = _tags.index( old_tag );
    if( index != -1 ) {
      _tags.remove_link( _tags.find_custom( old_tag, strcmp ) );
      _tags.insert( new_tag, index );
    }
  }

  /* Removes the given tag (if it exists in the list) */
  public void remove_tag( string tag ) {
    if( contains_tag( tag ) ) {
      _tags.remove_link( _tags.find_custom( tag, strcmp ) );
    }
  }

  /* Removes the items in the specified tag list from our tag list */
  public void remove_tag_list( TagList tags ) {
    tags.foreach((tag) => {
      if( contains_tag( tag ) ) {
        _tags.remove_link( _tags.find_custom( tag, strcmp ) );
      }
    });
  }

  /* Sorts the results */
  public void sort() {
    _tags.sort( strcmp );
  }

  /* Foreach function for the tag list */
  public void @foreach( ForeachFunc func ) {
    foreach( var tag in _tags ) {
      func( tag );
    }
  }

  /* Returns the number of items in the list */
  public int length() {
    return( (int)_tags.length() );
  }

  /* Returns the tag at the given index */
  public string get_tag( int index ) {
    return( _tags.nth_data( index ) );
  }

  /* Returns the tag list in the form suitable for display */
  public string load_tag_list() {
    string[] tag_array = {};
    foreach( string tag in _tags ) {
      tag_array += tag;
    }
    return( string.joinv( ", ", tag_array ) );
  }

  /* Stores the given comma-separated list as a list of tag strings */
  public void store_tag_list( string tag_list ) {
    var tag_array = tag_list.split( "," );
    foreach( string tag in tag_array ) {
      add_tag( tag.strip() );
    }
  }

  /* Outputs this as a string */
  public string to_string() {
    string[] tag_array = {};
    foreach( string tag in _tags ) {
      tag_array += tag;
    }
    return( string.joinv( ":", tag_array ) );
  }
}
