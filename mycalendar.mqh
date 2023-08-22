#define FILE_NAME "news/mynewshistory.bin"
#define MY_IMPORTANT_NEWS "CPI;Interest;Nonfarm;Unemployment;Employment;Jobless Claims;GDP;NFP;PMI;Retail Sale;Empire State Manufacturing;Fed Chair"

struct MyNewsStruct{ 
   string                              title;                 // Title
   ulong                               value_id;              // value ID
   ulong                               event_id;              // event ID
   datetime                            time;                  // event date and time
   ENUM_CALENDAR_EVENT_IMPORTANCE      importance;            // Importance
   double                              actual_value;          // actual value
   double                              prev_value;            // previous value
   double                              forecast_value;        // forecast value
   ENUM_CALENDAR_EVENT_IMPACT          impact_type;           // potential impact on the currency rate
}; 


struct EventHistoryStruct{
   ulong    value_id;
   ulong    event_id;
   datetime time;
   datetime period;
   int      revision;
   double     actual_value;
   double     prev_value;
   double     revised_prev_value;
   double     forecast_value;
   ENUM_CALENDAR_EVENT_IMPACT impact_type;
   ENUM_CALENDAR_EVENT_TYPE event_type;
   ENUM_CALENDAR_EVENT_SECTOR sector;
   ENUM_CALENDAR_EVENT_FREQUENCY frequency;
   ENUM_CALENDAR_EVENT_TIMEMODE timemode;
   ENUM_CALENDAR_EVENT_IMPORTANCE importance;
   ENUM_CALENDAR_EVENT_MULTIPLIER multiplier;
   ENUM_CALENDAR_EVENT_UNIT unit;
   uint     digits;
   ulong    country_id; // ISO 3166-1
};


enum ENUM_COUNTRY_ID{
   World=0,
   EU=999,
   USA=840,
   Canada=124,
   Australia=36,
   NewZealand=554,
   Japan=392,
   China=156,
   UK=826,
   Switzerland=756,
   Germany=276,
   France=250,
   Italy=380,
   Spain=724,
   Brazil=76,
   SouthKorea=410
};


string CountryIdToName(ENUM_COUNTRY_ID country_id){
   switch(country_id){
      case 999:      return "EU";     // EU
      case 840:      return "US";     // USA
      case 36:       return "AU";     // Australia
      case 554:      return "NZ";     // NewZealand
      case 156:      return "CY";     // China
      case 826:      return "GB";     // UK
      case 756:      return "CH";     // Switzerland
      case 124:      return "CA";     // Canada
      default:       return "";
   }
}  
  

int NameToCountryId(string name){
   if (name=="EU"){return 999;}
   if (name=="US"){return 840;}
   if (name=="AU"){return 36;}
   if (name=="NZ"){return 554;}
   if (name=="CY"){return 156;}
   if (name=="GB"){return 826;}
   if (name=="CH"){return 756;}
   if (name=="CA"){return 124;}
   return 0;
}


class CNews{
   private:
      void read_file(void);
      void read_live(void);
      datetime date_from;
      datetime date_to;
      string country_name;
      string filter_title;
      string filt[];
      int nfilt;
      bool is_title_pass_filter(string title);
   public:
      MyNewsStruct news[];
      CNews(void){};
      CNews(datetime date_from_, datetime date_to_, string country_name_="US", string filter_title_="");
     ~CNews(void){};
};



void CNews::CNews(datetime date_from_, datetime date_to_, string country_name_="US", string filter_title_=""){
   
   if(date_from_ == 0){
      MqlDateTime date_from_struct;
      TimeToStruct(TimeCurrent(), date_from_struct);
      date_from_struct.hour = 0;
      date_from_struct.min = 0;
      date_from_struct.sec = 0;
      date_from_ = StructToTime(date_from_struct);
   }
   date_from = date_from_;
   
   if(date_to_ == 0){
      MqlDateTime date_to_struct;
      TimeToStruct(TimeCurrent(), date_to_struct);
      date_to_struct.hour = 23;
      date_to_struct.min = 59;
      date_to_struct.sec = 59;
      date_to_ = StructToTime(date_to_struct);
   }
   date_to = date_to_;
   
   country_name = country_name_;
   StringReplace(country_name, " ", "");
   
   filter_title = filter_title_;
   StringReplace(filter_title, " ", "");
   StringToLower(filter_title);
   string sep=";";
   ushort u_sep;
   u_sep = StringGetCharacter(sep, 0);
   nfilt = StringSplit(filter_title, u_sep, filt);

   if(MQLInfoInteger(MQL_DEBUG) || MQLInfoInteger(MQL_FORWARD) || MQLInfoInteger(MQL_OPTIMIZATION) || MQLInfoInteger(MQL_VISUAL_MODE) || MQLInfoInteger(MQL_TESTER)) read_file();
   else read_live();
}


void CNews::read_file(void){
   int filehandle;
   if (FileIsExist(FILE_NAME,FILE_COMMON)){
      filehandle=FileOpen(FILE_NAME,FILE_READ|FILE_COMMON|FILE_BIN);
      FileSeek(filehandle,0,SEEK_SET);
      if (filehandle==INVALID_HANDLE){
         Print(__FUNCTION__,": can't open previous news history file; invalid file handle");
         return;
      }
    
      int n=0;
      ArrayResize(news,n,100);
      while(!FileIsEnding(filehandle) && !IsStopped()){
         EventHistoryStruct event;
         string eventname;
         FileReadStruct(filehandle,event);
         int length=FileReadInteger(filehandle,INT_VALUE);
         eventname=FileReadString(filehandle,length);
         ulong country_id = NameToCountryId(country_name);
         if(event.time>=date_from && event.time<=date_to && event.country_id==country_id){
            if(!is_title_pass_filter(eventname)) continue;
            n++;
            ArrayResize(news,n,100);
            news[n-1].value_id=event.value_id;
            news[n-1].event_id=event.event_id; 
            news[n-1].time=event.time; 
            news[n-1].impact_type=event.impact_type; 
            news[n-1].importance = event.importance;
            news[n-1].title = eventname;
            news[n-1].actual_value=event.actual_value; 
            news[n-1].prev_value=event.prev_value; 
            news[n-1].forecast_value=event.forecast_value;
         }
      }
      FileClose(filehandle);
      Print(__FUNCTION__,": loading of event history completed (",n," events)");
   }else{
      Print(__FUNCTION__,": no newshistory file found");
   }

}


void CNews::read_live(void){
   MqlCalendarValue values[]; 
   if(!CalendarValueHistory(values, date_from, date_to, country_name)){ 
      PrintFormat("Error! Failed to get events for country_code=%s", country_name); 
      PrintFormat("Error code: %d", GetLastError()); 
      return; 
   }
  
   int total=ArraySize(values); 
   int n = 0;
   for(int i=0; i<total; i++){ 
      MqlCalendarEvent event_;
      CalendarEventById(values[i].event_id, event_);
      if(!is_title_pass_filter(event_.name)) continue;
      n++;
      ArrayResize(news, n, total);
      news[n-1].value_id=values[i].id; 
      news[n-1].event_id=values[i].event_id; 
      news[n-1].time=values[i].time; 
      news[n-1].impact_type=values[i].impact_type; 
      news[n-1].importance = event_.importance;
      news[n-1].title = event_.name;
      news[n-1].actual_value=values[i].GetActualValue(); 
      news[n-1].prev_value=values[i].GetPreviousValue(); 
      news[n-1].forecast_value=values[i].GetForecastValue(); 
   }
}


bool CNews::is_title_pass_filter(string title){
   if(nfilt>0){
      string t = title;
      StringToLower(t);
      StringReplace(t, " ", "");
      for(int k=0;k<nfilt;k++){
         if(StringFind(t, filt[k], 0)>-1) return true;
      }
      return false;
   }
   return true;
}