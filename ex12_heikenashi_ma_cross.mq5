#include <../Experts/mq5ea/mytools.mqh>

input ENUM_TIMEFRAMES slow_tf = PERIOD_H3;
input ENUM_TIMEFRAMES fast_tf = PERIOD_H1;
//input int slow_tf_shift = 0;
//input int fast_tf_shift = 0;
input int ma_slow_period = 30;
input int ma_fast_period = 1;
input int ma_slow_shift = 0;
input int ma_fast_shift = 0;
input double LotSize = 0.1;
input string session_start_time = "09:00";      // session start (server time)
input string session_end_time = "19:00";        // session end (server time)    
input int Magic = 120;

int slow_heiken_ashi_handle, fast_heiken_ashi_handle;

#define HA_MA_BUFFER 5

int OnInit()
{  
   slow_heiken_ashi_handle = iCustom(_Symbol, slow_tf, "..\\Experts\\mq5ea\\indicators\\heiken_ashi_ema.ex5");
   ObjectsDeleteAll(0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{

}

void OnTick()
{  
   double slow_ma[];
   CopyBuffer(slow_heiken_ashi_handle, HA_MA_BUFFER, 1, 3, slow_ma);
}

void OnTrade()
{

}
