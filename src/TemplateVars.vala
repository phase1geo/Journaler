public class CallbackParam {

  /* Constructor */
  public CallbackParam() {}

  /* Returns the parameter as a string for debug */
  public virtual string to_string() {
    return( "" );
  }

}

public class NewsSource : CallbackParam {

  public string name;
  public string feed;
  public int    num_items;

  /* Default constructor */
  public NewsSource( string name, string feed, int num_items ) {
    this.name      = name;
    this.feed      = feed;
    this.num_items = num_items;
  }

  public override string to_string() {
    return( "name: %s, feed: %s, num_items: %d".printf( name, feed, num_items ) );
  }

}

public class TemplateVars {

  private Gee.HashMap<string,string> _vars;
  private Array<NewsSource>          _news_sources;
  private int                        _exp_var_num = 0;

  public signal void changed();

  public delegate void RunCommandCallback( string output, CallbackParam? param );
  public delegate void VariableWaitCallback( CallbackParam? param );

  /* Default constructor */
  public TemplateVars() {

    _vars = new Gee.HashMap<string,string>();
    _news_sources = new Array<NewsSource>();

    Idle.add(() => {
      collect_variables();
      return( false );
    });

  }

  /* Runs the given command as a subprocess and allows access to standard output text */
  private void run_command( string command, RunCommandCallback callback, CallbackParam? param = null ) {

    try {

      string[] spawn_args = command.split( " " );
      string[] spawn_env = Environ.get ();
      Pid child_pid;
      int std_in, std_out, std_err;

      Process.spawn_async_with_pipes(
        "/",
        spawn_args,
        spawn_env,
        SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
        null,
        out child_pid,
        out std_in,
        out std_out,
        out std_err
      );

      var retstr = "";
      var output = new IOChannel.unix_new( std_out );
      output.add_watch( IOCondition.IN | IOCondition.HUP, (channel, condition) => {
        if (condition == IOCondition.HUP) {
          return false;
        }
        try {
          string line;
          channel.read_line( out line, null, null );
          retstr += line;
        } catch( IOChannelError e ) {
          return false;
        } catch( ConvertError e ) {
          return false;
        }
  	    return( true );
      });

      ChildWatch.add( child_pid, (pid, status) => {
        callback( retstr, param );
        Process.close_pid( pid );
      });

    } catch( SpawnError e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }

  }

  /* Retrieves the daily weather */
  private void get_weather_and_location() {
    var lang = Environment.get_variable( "LANGUAGE" );
    _exp_var_num += 3;
    run_command( "wget -q -O - wttr.in/?1TFqn&lang=%s".printf( lang ), (output, param) => {
      string[] lines = output.split( "\n" );
      if( lines.length > 0 ) {
        _vars.set( "WEATHER_TEXT", get_weather_text( lines[2:3] ) );
        _vars.set( "WEATHER", "```\n" + string.joinv( "\n", lines[7:lines.length-1] ).chomp()  + "\n```" );
        _vars.set( "LOCATION", lines[0].strip() );
      }
    });
  }

  /* Returns the weather in text-only format */
  private string get_weather_text( string[] lines ) {

    var condition   = lines[0].substring( lines[0].index_of_nth_char( 16 ) ).strip();
    var temperature = lines[1].substring( lines[1].index_of_nth_char( 16 ) ).strip();

    return( "%s, %s".printf( condition, temperature ) );

  }

  /* Makes a valid variable */
  private string make_variable( string str ) {
    return( str.replace( " ", "_" ).up() );
  }

  /* Creates the NEWS_* variable name for the given feed source name */
  private string make_news_variable( string name ) {
    return( make_variable( "NEWS_%s".printf( name ) ) );
  }

  /* Gets the daily news from the stored RSS feeds */
  private void get_news( NewsSource source ) {

    var name  = make_news_variable( source.name );

    _exp_var_num++;
    _vars.unset( name );

    run_command( "wget -q -O - %s".printf( source.feed ), (output, param) => {
      var src = (NewsSource)param;
      var rss = new RSS( output, src.num_items );
      _vars.set( make_news_variable( src.name ), rss.items );
    }, source );

  }

  /* Updates the news items and saves them */
  public void update_news() {

    /* Loads the news source data */
    for( int i=0; i<_news_sources.length; i++ ) {
      get_news( _news_sources.index( i ) );
    }

    wait_for_variables((param) => {
      save();
      changed();
    });

  }

  /* Clears the current news sources */
  public void clear_news_sources() {
    for( int i=0; i<_news_sources.length; i++ ) {
      _vars.unset( make_news_variable( _news_sources.index( i ).name ) );
      _exp_var_num--;
    }
    _news_sources.set_size( 0 );
  }

  /* Adds a news source to the list (which updates the settings) */
  public void add_news_source( NewsSource source ) {
    _news_sources.append_val( source );
  }

  /* Returns the number of stored news sources */
  public int num_news_source() {
    return( (int)_news_sources.length );
  }

  /* Retrieves the news source from the list */
  public NewsSource get_news_source( int index ) {
    return( _news_sources.index( index ) );
  }

  /* Saves the news sources to the glib.settings */
  public void save_news_sources() {

    Variant[] variants = {};

    for( int i=0; i<_news_sources.length; i++ ) {
      var source = _news_sources.index( i );
      variants += new Variant( "(ssi)", source.name, source.feed, source.num_items );
    }

    var variant_type = new VariantType( "(ssi)" );
    var variant = new Variant.array( variant_type, variants );
    Journaler.settings.set_value( "news-feeds", variant );

  }

  /* Loads the news sources from glib.settings */
  private void load_news_sources() {

    var variant = Journaler.settings.get_value( "news-feeds" );

    string? val1 = null;
    string? val2 = null;
    int     val3 = -1;

    var iter = new VariantIter( variant );
    while( iter.next( "(ssi)", out val1, out val2, out val3 ) ) {
      var news_source = new NewsSource( val1, val2, val3 );
      _news_sources.append_val( news_source );
    }

  }

  /* Waits for the variables to be retrieved and then calls the given callback */
  public void wait_for_variables( VariableWaitCallback callback, CallbackParam? param = null ) {

    Timeout.add( 200, () => {
      stdout.printf( "vars.size: %u, exp_var_num: %d, param: %s\n", _vars.size, _exp_var_num, ((param == null) ? "NA" : param.to_string()) );
      if( (_exp_var_num > 0) && (_vars.size == _exp_var_num) ) {
        callback( param );
        return( false );
      } else {
        stdout.printf( "Variables:\n" );
        _vars.map_iterator().foreach((k,v) => {
          stdout.printf( "  %s\n", k );
          return( true );
        });
      }
      return( true );
    });

  }

  /* Collects the variables into the _vars array */
  public void collect_variables() {

    /* Load the new sources from settings */
    load_news_sources();

    /* Attempt to load the template variable data.  If it is old or doesn't exist, reload the data */
    if( !load() ) {

      /* Loads the weather and location data */
      get_weather_and_location();

      /* Loads the news source data */
      for( int i=0; i<_news_sources.length; i++ ) {
        get_news( _news_sources.index( i ) );
      }

      /* Wait for the variables to be collected */
      wait_for_variables((param) => {
        save();
        changed();
      });

      /* Saves the loaded variables */
      save();

    } else {
      changed();
    }

  }

  /* Returns the number of available variables */
  public int num_variables() {
    return( _vars.size );
  }

  /* Returns the variable at the given location */
  public string get_variable( int index ) {
    var name = "";
    var num  = 0;
    _vars.map_iterator().foreach((key, val) => {
      if( num++ == index ) {
        name = key;
        return( false );
      }
      return( true );
    });
    return( name );
  }

  /* Adds the available variable values to the provided snippet */
  public void set_variables( GtkSource.Snippet snippet ) {
    _vars.map_iterator().foreach((key, val) => {
      snippet.get_context().set_constant( key, val );
      return( true );
    });
  }

  /* Returns today's date */
  private string todays_date() {
    var today = new DateTime.now_local();
    return( "%04d-%02d-%02d".printf( today.get_year(), today.get_month(), today.get_day_of_month() ) );
  }

  /* Returns the pathname of the template_vars.xml file */
  private string xml_file() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "template_vars.xml" ) );
  }

  /* Saves the variables in the template_vars XML file */
  public void save() {

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "variables" );

    root->set_prop( "date", todays_date() );

    _vars.map_iterator().foreach((k,v) => {
      Xml.Node* node = new Xml.Node( null, "variable" );
      node->set_prop( "name", k );
      node->set_content( v );
      root->add_child( node );
      return( true );
    });

    doc->set_root_element( root );
    doc->save_format_file( xml_file(), 1 );

    delete doc;

  }

  /* Loads the available templates from XML format */
  public bool load() {

    Xml.Doc* doc = Xml.Parser.read_file( xml_file(), null, (Xml.ParserOption.HUGE | Xml.ParserOption.NOWARNING) );
    if( doc == null ) {
      return( false );
    }

    Xml.Node* root = doc->get_root_element();

    /* Check the date of the file, if it is old we will load them another way */
    var today = root->get_prop( "date" );
    if( (today != null) && (today != todays_date()) ) {
      return( false );
    }

    for( Xml.Node* it = root->children; it != null; it = it->next ) {
      if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "variable") ) {
        var n = it->get_prop( "name" );
        if( n != null ) {
          _vars.set( n, it->get_content() );
        }
      }
    }

    delete doc;

    return( true );

  }

}
