#include <../Experts/mq5ea/mycalendar.mqh>

datetime date_from=D'01.01.2015 00:00';
datetime date_to=D'31.12.2023 23:59';

void OnStart(){
   MqlCalendarValue eventvaluebuffer[];ZeroMemory(eventvaluebuffer);
   CalendarValueHistory(eventvaluebuffer,date_from,date_to);
   
   int number_of_events=ArraySize(eventvaluebuffer);
   int saved_elements=0;

   for (int i=0;i<number_of_events;i++)
     {
      MqlCalendarEvent eventbuffer;ZeroMemory(eventbuffer);
      EventHistoryStruct event;ZeroMemory(event);
      event.value_id          =  eventvaluebuffer[i].id;
      event.event_id          =  eventvaluebuffer[i].event_id;
      event.time              =  eventvaluebuffer[i].time;
      event.period            =  eventvaluebuffer[i].period;
      event.revision          =  eventvaluebuffer[i].revision;
      event.actual_value      =  eventvaluebuffer[i].GetActualValue();
      event.prev_value        =  eventvaluebuffer[i].GetPreviousValue();
      event.revised_prev_value=  eventvaluebuffer[i].GetRevisedValue();
      event.forecast_value    =  eventvaluebuffer[i].GetForecastValue();
      event.impact_type       =  eventvaluebuffer[i].impact_type;
      
      CalendarEventById(event.event_id,eventbuffer);
      
      event.event_type        =  eventbuffer.type;
      event.sector            =  eventbuffer.sector;
      event.frequency         =  eventbuffer.frequency;
      event.timemode          =  eventbuffer.time_mode;
      event.importance        =  eventbuffer.importance;
      event.multiplier        =  eventbuffer.multiplier;
      event.unit              =  eventbuffer.unit;
      event.digits            =  eventbuffer.digits;
      event.country_id        =  eventbuffer.country_id;
      if (event.event_type!=CALENDAR_TYPE_HOLIDAY &&           // ignore holiday events
         event.timemode==CALENDAR_TIMEMODE_DATETIME)           // only events with exactly published time
        {
         MqlDateTime eventdate;
         TimeToStruct(event.time, eventdate);
         string filename = StringFormat("news/%4d%02d", eventdate.year, eventdate.mon);
         int filehandle;
         filehandle=FileOpen(filename,FILE_READ|FILE_WRITE|FILE_COMMON|FILE_BIN);
         if(filehandle!=INVALID_HANDLE) Print(__FUNCTION__,": writing news to file ", filename);
         else Print(__FUNCTION__,": cannot open file ", filename);
         FileSeek(filehandle,0,SEEK_END);
         FileWriteStruct(filehandle,event);
         int length=StringLen(eventbuffer.name);
         FileWriteInteger(filehandle,length,INT_VALUE);
         FileWriteString(filehandle,eventbuffer.name,length);
         FileClose(filehandle);
         saved_elements++;
        }
     }
     Print(__FUNCTION__,": ",number_of_events," total events found, ",saved_elements,
      " events saved (holiday events and events without exact published time are ignored)");
}