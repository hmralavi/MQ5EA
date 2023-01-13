/*
news scalpinm EA

Strategy:
   1- before a high impact news, place two orders: buy stop and sell stop
   2- the orders must be placed by an offset to the price right before the news
   3- delete all orders after certain time after the news
   
*/

#include <../Experts/mq5ea/mytools.mqh>
#include <../Experts/mq5ea/mycalendar.mqh>

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

int OnInit(){

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{

}

void OnTick()
{  
   static int last_day;
   MqlDateTime today;
   TimeToStruct(TimeCurrent(), today);
   if(last_day != today.day){
      last_day = today.day;
      CNews news(0,0,"US","");
      ArrayPrint(news.news);
   }

}

