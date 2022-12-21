/*
news scalpinm EA

Strategy:
   1- before a high impact news, place two orders: buy stop and sell stop
   2- the orders must be placed by an offset to the price right before the news
   3- delete all orders after certain time after the news
   
*/

#include <../Experts/mq5ea/mytools.mqh>

input double orders_offset_points = 200;
input double sl_points = 100;  // sl points 
input double tp_points = 500; // reward/risk ratio
input double lot = 0.1;  // lot size

input group "Trailing stoploss"
input bool trailing_stoploss = true;
input double tsl_offset_points = 30;
input double tsl_trigger_points = 30;

input int Magic = 190;  // EA's magic number

CTrade trade;

int OnInit()
{

//--- country code for EU (ISO 3166-1 Alpha-2) 
//--- country code for EU (ISO 3166-1 Alpha-2) 
   string EU_code="US"; 
//--- get all EU event values 
   MqlCalendarValue values[]; 
//--- set the boundaries of the interval we take the events from 
   datetime date_from=D'16.12.2022';  // take all events from 2018 
   datetime date_to=0;                // 0 means all known events, including the ones that have not occurred yet  
//--- request EU event history since 2018 year 
   if(CalendarValueHistory(values,date_from,date_to,EU_code)) 
     { 
      PrintFormat("Received event values for country_code=%s: %d", 
                  EU_code,ArraySize(values)); 
      //--- decrease the size of the array for outputting to the Journal 
      ArrayResize(values,10); 
//--- display event values in the Journal 
      ArrayPrint(values);       
     } 
   else 
     { 
      PrintFormat("Error! Failed to receive events for country_code=%s",EU_code); 
      PrintFormat("Error code: %d",GetLastError()); 
     } 
   trade.SetExpertMagicNumber(Magic);
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{

}

void OnTick()
{
  

}

