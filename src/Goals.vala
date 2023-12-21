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

public class Goals {

  private MainWindow               _win;
  private Array<Goal>              _goals;
  private Gee.HashMap<string,Goal> _hash;

  /* Default constructor */
  public Goals( MainWindow win ) {

    _win   = win;
    _goals = new Array<Goal>();
    _hash  = new Gee.HashMap<string,Goal>();

    add_goal( new GoalStreak( _( "First entry" ),         1 ) );
    add_goal( new GoalStreak( _( "Two days in a Row" ),   2 ) );
    add_goal( new GoalStreak( _( "Three days in a Row" ), 3 ) );
    add_goal( new GoalStreak( _( "Five days in a Row" ),  5 ) );
    add_goal( new GoalStreak( _( "One Week in a Row" ),   days_in_week( 1 ) ) );
    add_goal( new GoalStreak( _( "Two Weeks in a Row" ),  days_in_week( 2 ) ) );
    add_goal( new GoalStreak( _( "One month in a Row" ),  days_in_month( 1 ) ) );
    add_goal( new GoalStreak( _( "Two months in a Row" ), days_in_month( 2 ) ) );
    add_goal( new GoalStreak( _( "Six months in a Row" ), days_in_month( 6 ) ) );
    add_goal( new GoalStreak( _( "One year in a Row" ),   days_in_year( 1 ) ) );
    add_goal( new GoalStreak( _( "Two years in a Row" ),  days_in_year( 2 ) ) );
    add_goal( new GoalStreak( _( "Five years in a Row" ), days_in_year( 5 ) ) );

    add_goal( new GoalCount( _( "10 entries" ), 10 ) );
    add_goal( new GoalCount( _( "20 entries" ), 20 ) );
    add_goal( new GoalCount( _( "50 entries" ), 50 ) );
    add_goal( new GoalCount( _( "100 entries" ), 100 ) );
    add_goal( new GoalCount( _( "200 entries" ), 200 ) );
    add_goal( new GoalCount( _( "500 entries" ), 500 ) );
    add_goal( new GoalCount( _( "1000 entries" ), 1000 ) );

    add_goal( new GoalMinimum( _( "1 day per week for 1 month" ),   1, SubGoalDuration.WEEK, 4 ) );
    add_goal( new GoalMinimum( _( "1 day per week for 2 months" ),  1, SubGoalDuration.WEEK, 8 ) );
    add_goal( new GoalMinimum( _( "1 day per week for 3 months" ),  1, SubGoalDuration.WEEK, 13 ) );
    add_goal( new GoalMinimum( _( "1 day per week for 6 months" ),  1, SubGoalDuration.WEEK, 26 ) );
    add_goal( new GoalMinimum( _( "1 day per week for 9 months" ),  1, SubGoalDuration.WEEK, 39 ) );
    add_goal( new GoalMinimum( _( "1 day per week for 12 months" ), 1, SubGoalDuration.WEEK, 52 ) );

    add_goal( new GoalMinimum( _( "2 days per week for 1 month" ),   2, SubGoalDuration.WEEK, 4 ) );
    add_goal( new GoalMinimum( _( "2 days per week for 2 months" ),  2, SubGoalDuration.WEEK, 8 ) );
    add_goal( new GoalMinimum( _( "2 days per week for 3 months" ),  2, SubGoalDuration.WEEK, 13 ) );
    add_goal( new GoalMinimum( _( "2 days per week for 6 months" ),  2, SubGoalDuration.WEEK, 26 ) );
    add_goal( new GoalMinimum( _( "2 days per week for 9 months" ),  2, SubGoalDuration.WEEK, 39 ) );
    add_goal( new GoalMinimum( _( "2 days per week for 12 months" ), 2, SubGoalDuration.WEEK, 52 ) );

    add_goal( new GoalMinimum( _( "3 days per week for 1 month" ),   3, SubGoalDuration.WEEK, 4 ) );
    add_goal( new GoalMinimum( _( "3 days per week for 2 months" ),  3, SubGoalDuration.WEEK, 8 ) );
    add_goal( new GoalMinimum( _( "3 days per week for 3 months" ),  3, SubGoalDuration.WEEK, 13 ) );
    add_goal( new GoalMinimum( _( "3 days per week for 6 months" ),  3, SubGoalDuration.WEEK, 26 ) );
    add_goal( new GoalMinimum( _( "3 days per week for 9 months" ),  3, SubGoalDuration.WEEK, 39 ) );
    add_goal( new GoalMinimum( _( "3 days per week for 12 months" ), 3, SubGoalDuration.WEEK, 52 ) );

    add_goal( new GoalMinimum( _( "5 days per week for 1 month" ),   5, SubGoalDuration.WEEK, 4 ) );
    add_goal( new GoalMinimum( _( "5 days per week for 2 months" ),  5, SubGoalDuration.WEEK, 8 ) );
    add_goal( new GoalMinimum( _( "5 days per week for 3 months" ),  5, SubGoalDuration.WEEK, 13 ) );
    add_goal( new GoalMinimum( _( "5 days per week for 6 months" ),  5, SubGoalDuration.WEEK, 26 ) );
    add_goal( new GoalMinimum( _( "5 days per week for 9 months" ),  5, SubGoalDuration.WEEK, 39 ) );
    add_goal( new GoalMinimum( _( "5 days per week for 12 months" ), 5, SubGoalDuration.WEEK, 52 ) );

    add_goal( new GoalMinimum( _( "5 days per month for 1 month" ),   5, SubGoalDuration.MONTH, 1 ) );
    add_goal( new GoalMinimum( _( "5 days per month for 2 months" ),  5, SubGoalDuration.MONTH, 2 ) );
    add_goal( new GoalMinimum( _( "5 days per month for 3 months" ),  5, SubGoalDuration.MONTH, 3 ) );
    add_goal( new GoalMinimum( _( "5 days per month for 6 months" ),  5, SubGoalDuration.MONTH, 6 ) );
    add_goal( new GoalMinimum( _( "5 days per month for 9 months" ),  5, SubGoalDuration.MONTH, 9 ) );
    add_goal( new GoalMinimum( _( "5 days per month for 12 months" ), 5, SubGoalDuration.MONTH, 12 ) );

    add_goal( new GoalMinimum( _( "10 days per month for 1 month" ),   10, SubGoalDuration.MONTH, 1 ) );
    add_goal( new GoalMinimum( _( "10 days per month for 2 months" ),  10, SubGoalDuration.MONTH, 2 ) );
    add_goal( new GoalMinimum( _( "10 days per month for 3 months" ),  10, SubGoalDuration.MONTH, 3 ) );
    add_goal( new GoalMinimum( _( "10 days per month for 6 months" ),  10, SubGoalDuration.MONTH, 6 ) );
    add_goal( new GoalMinimum( _( "10 days per month for 9 months" ),  10, SubGoalDuration.MONTH, 9 ) );
    add_goal( new GoalMinimum( _( "10 days per month for 12 months" ), 10, SubGoalDuration.MONTH, 12 ) );

    add_goal( new GoalMinimum( _( "20 days per month for 1 month" ),   20, SubGoalDuration.MONTH, 1 ) );
    add_goal( new GoalMinimum( _( "20 days per month for 2 months" ),  20, SubGoalDuration.MONTH, 2 ) );
    add_goal( new GoalMinimum( _( "20 days per month for 3 months" ),  20, SubGoalDuration.MONTH, 3 ) );
    add_goal( new GoalMinimum( _( "20 days per month for 6 months" ),  20, SubGoalDuration.MONTH, 6 ) );
    add_goal( new GoalMinimum( _( "20 days per month for 9 months" ),  20, SubGoalDuration.MONTH, 9 ) );
    add_goal( new GoalMinimum( _( "20 days per month for 12 months" ), 20, SubGoalDuration.MONTH, 12 ) );

  }

  /* Adds a new goal to the list */
  private void add_goal( Goal goal ) {
    _goals.append_val( goal );
    _hash.set( goal.name, goal );
  }

  /* Merges the given goal with an existing goal */
  private void merge_goal( Goal goal ) {
    if( _hash.has_key( goal.name ) ) {
      _hash.get( goal.name ).merge( goal );
    }
  }

  /* Returns the number of goals stored */
  public int size() {
    return( (int)_goals.length );
  }

  /* Returns the goal stored at the given index */
  public Goal index( int i ) {
    return( _goals.index( i ) );
  }

  /* Returns the achievement status label */
  public string get_achievement_status() {
    var achieved = 0;
    for( int i=0; i<_goals.length; i++ ) {
      if( _goals.index( i ).achieved ) {
        achieved++;
      }
    }
    return( _( "Achieved %d out of %d awards" ).printf( achieved, size() ) );
  }

  /* Checks for any achievements when an entry meets an entry goal (on save only) */
  public void mark_achievement( string entry_date ) {
    var todays_date = DBEntry.todays_date();
    if( todays_date == entry_date ) {
      string[] notify_msgs = {};
      bool     save_needed = false;
      for( int i=0; i<_goals.length; i++ ) {
        bool achieved;
        save_needed |= _goals.index( i ).mark_achievement( todays_date, out achieved );
        if( achieved ) {
          notify_msgs += _goals.index( i ).label;
        }
      }
      if( save_needed ) {
        save();
      }
      if( notify_msgs.length == 1 ) {
        _win.notification( _( "New Reward Achieved!" ), notify_msgs[0] );
      } else if( notify_msgs.length > 1 ) {
        _win.notification( _( "New Rewards Achieved!" ), string.joinv( "\n", notify_msgs ) );
      }
    }
  }

  /* Allows us to test the achievement system */
  public void test_achievement( string goal_name, string entry_date ) {
    if( _hash.has_key( goal_name ) ) {
      var goal = _hash.get( goal_name );
      bool achieved;
      goal.mark_achievement( entry_date, out achieved );
      if( achieved ) {
        stdout.printf( "Achieved goal %s (%s)\n", goal.label, entry_date );
      }
    } else {
      stderr.printf( "Key (%s) does not exist\n", goal_name );
    }
  }

  /* Returns the number of days in a week */
  private int days_in_week( int num_weeks ) {
    return( 7 * num_weeks );
  }

  /* Returns the average number of days in a month */
  private int days_in_month( int num_months ) {
    return( 30 * num_months );
  }

  /* Returns the number of days in a year */
  private int days_in_year( int num_years ) {
    return( 365 * num_years );
  }

  /* Returns the pathname of the XML file */
  private string xml_file() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "goals.xml" ) );
  }

  /* Saves the goal information in XML format */
  public void save() {

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "goals" );

    root->set_prop( "version", Journaler.version );

    for( int i=0; i<_goals.length; i++ ) {
      root->add_child( _goals.index( i ).save() );
    }

    doc->set_root_element( root );
    doc->save_format_file( xml_file(), 1 );

    delete doc;

  }

  /* Loads the stored goal information in XML format */
  public void load() {

    Xml.Doc* doc = Xml.Parser.read_file( xml_file(), null, (Xml.ParserOption.HUGE | Xml.ParserOption.NOWARNING) );
    if( doc == null ) {
      return;
    }

    Xml.Node* root = doc->get_root_element();

    var version = root->get_prop( "version" );
    if( version != null ) {
      check_version( version );
    }

    for( Xml.Node* it = doc->get_root_element()->children; it != null; it = it->next ) {
      if( it->type == Xml.ElementType.ELEMENT_NODE ) {
        Goal? goal = null;
        switch( it->name ) {
          case "goal-streak" :  goal = new GoalStreak.from_xml( it );  break;
          case "goal-count"  :  goal = new GoalCount.from_xml( it );   break;
        }
        if( goal != null ) {
          merge_goal( goal );
        }
      }
    }

    delete doc;

  }

  /* Allows us to make upgrades based on version information */
  private void check_version( string version ) {

    // TBD

  }

}
