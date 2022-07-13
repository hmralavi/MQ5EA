/*

TODO: 

*/
#include <../Experts/mq5ea/mytools.mqh>

input ENUM_TIMEFRAMES MinorTF = PERIOD_M5;
input ENUM_TIMEFRAMES MajorTF = PERIOD_H1;
input int NCandlesMinorTF = 500;
input int NCandlesMajorTF = 500;
input int NCandlesPeak = 6;
input double LotSize = 0.1;
input int SlPoints = 300;
input double RRatio = 4;
input bool TSL_Enabled = true;  // Trailing stoploss enabled
input int Magic = 110;

CTrade trade;

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{

}

void OnTick()
{
   ulong pos_tickets[];
   GetMyPositionsTickets(Magic, pos_tickets);
   int npos = ArraySize(pos_tickets);
   if(npos>0){
      DeleteAllOrders(trade);
      if(TSL_Enabled){
         for(int i=0; i<npos; i++) TrailingStoploss(trade, pos_tickets[i], SlPoints, 2*SlPoints);
      }
      return;
   }
   if(!IsNewCandle(MinorTF)) return;
   
   //double peak_levels[];
   //datetime peak_times[];
   //int peak_shifts[];
   //bool peak_tops[];
   //DetectPeaks(peak_levels, peak_times, peak_shifts, peak_tops, MajorTF, 0, NCandlesHistory, NCandlesPeak);

   double ob_major_zones[][2];
   datetime ob_major_times[][2];
   int ob_major_shifts[][2];
   bool ob_major_isDemandZone[];
   bool ob_major_isMitigated[];   
   DetectOrderBlocks(ob_major_zones, ob_major_times, ob_major_shifts, ob_major_isDemandZone, ob_major_isMitigated, MajorTF, 0, NCandlesMajorTF, NCandlesPeak);

   double ob_minor_zones[][2];
   datetime ob_minor_times[][2];
   int ob_minor_shifts[][2];
   bool ob_minor_isDemandZone[];
   bool ob_minor_isMitigated[];   
   DetectOrderBlocks(ob_minor_zones, ob_minor_times, ob_minor_shifts, ob_minor_isDemandZone, ob_minor_isMitigated, MinorTF, 0, NCandlesMinorTF, NCandlesPeak);

   
   ObjectsDeleteAll(0);
   PlotOrderBlocks(ob_major_zones, ob_major_times, ob_major_isDemandZone, ob_major_isMitigated, "major", STYLE_SOLID);
   PlotOrderBlocks(ob_minor_zones, ob_minor_times, ob_minor_isDemandZone, ob_minor_isMitigated, "minor", STYLE_DOT);
   ChartRedraw(0);
   Sleep(100);
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   
}
  

