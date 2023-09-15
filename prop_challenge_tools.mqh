#include <../Experts/mq5ea/mytools.mqh>

class PeriodData
{
public:
   int magic_number;
   datetime datetime_start;
   datetime datetime_end;
   double profit;
   double profit_max;
   double profit_min;
   void PeriodData(void);
   void PeriodData(int magic, int period_range=0); // period_range 0 means current month, 1 means current day
   void update(void);
};

class PropChallengeCriteria
{
protected:
   PeriodData period_data[];
   double min_profit_usd;
   double max_drawdown_usd;
   int magic_number;
   ENUM_MONTH period_month;
   bool is_drawdown_passed(const PeriodData& pdata);
   bool is_profit_passed(const PeriodData& pdata);
   bool is_period_passed(const PeriodData& pdata);
  
public:
   void PropChallengeCriteria(void);
   void PropChallengeCriteria(double min_profit_usd, double max_drawdown_usd, ENUM_MONTH period_month, int magic);
   void update(void);
   double get_current_period_profit(void);
   double get_current_period_drawdown(void);
   bool is_current_period_drawdown_passed(void);
   bool is_current_period_profit_passed(void);
   bool is_current_period_passed(void);
   double get_results(datetime& passed_periods[]);
   double get_today_profit(void);
};


void PeriodData::PeriodData(void){

}

void PeriodData::PeriodData(int magic, int period_range=0){
   MqlDateTime time_start, time_end;
   TimeToStruct(TimeCurrent(), time_start);
   TimeToStruct(TimeCurrent(), time_end);
   if(period_range==0){
      time_start.day=1;
      if(time_end.mon==4 || time_end.mon==6 || time_end.mon==9 || time_end.mon==11) time_end.day=30;
      else if(time_end.mon==2) time_end.day=28;
      else time_end.day=31;     
   }
   time_start.hour=0;
   time_start.min=0;
   time_start.sec=0;
   time_end.hour=23;
   time_end.min=59;
   time_end.sec=59;

   datetime_start = StructToTime(time_start);
   datetime_end = StructToTime(time_end);
   magic_number = magic;
   profit = 0;
   profit_max = 0;
   profit_min = 0;
}

void PeriodData::update(void){
   double _prof = 0;
   HistorySelect(datetime_start, datetime_end);
   int ndeals = HistoryDealsTotal();
   for(int i=0;i<ndeals;i++){
      ulong dealticket = HistoryDealGetTicket(i);
      int magic = (int)HistoryDealGetInteger(dealticket, DEAL_MAGIC);
      if(magic != magic_number) continue;
      _prof += HistoryDealGetDouble(dealticket, DEAL_PROFIT) + HistoryDealGetDouble(dealticket, DEAL_COMMISSION) + HistoryDealGetDouble(dealticket, DEAL_FEE) + HistoryDealGetDouble(dealticket, DEAL_SWAP);
   }
   ulong pos_tickets[];
   GetMyPositionsTickets(magic_number, pos_tickets);
   int npos = ArraySize(pos_tickets);
   for(int ipos=0;ipos<npos;ipos++){
      PositionSelectByTicket(pos_tickets[ipos]);
      _prof += PositionGetDouble(POSITION_PROFIT);
   }
   profit = _prof;
   if(profit>profit_max) profit_max = profit;
   if(profit<profit_min) profit_min = profit;
}

void PropChallengeCriteria::PropChallengeCriteria(void){

}

void PropChallengeCriteria::PropChallengeCriteria(double min_profit_usd_, double max_drawdown_usd_, ENUM_MONTH period_month_, int magic){
   min_profit_usd = min_profit_usd_;
   max_drawdown_usd = max_drawdown_usd_;
   period_month = period_month_;
   magic_number = magic;
}

void PropChallengeCriteria::update(void){
   int ndata = ArraySize(period_data);
   MqlDateTime current_time;
   TimeToStruct(TimeCurrent(), current_time);
   if(ndata>0){
      MqlDateTime last_period_time;
      TimeToStruct(period_data[ndata-1].datetime_end, last_period_time);
      if(last_period_time.year==current_time.year && last_period_time.mon==current_time.mon){
         period_data[ndata-1].update();
      }else if(current_time.mon==period_month || period_month==MONTH_ALL){
         ArrayResize(period_data, ndata+1);
         period_data[ndata] = PeriodData(magic_number);
      } 
   }else if(current_time.mon==period_month || period_month==MONTH_ALL){
      ArrayResize(period_data, 1);
      period_data[0] = PeriodData(magic_number);
   }
}

bool PropChallengeCriteria::is_drawdown_passed(const PeriodData &pdata){
   bool is_passed;
   is_passed = pdata.profit_min>=-max_drawdown_usd;
   return is_passed;
}

bool PropChallengeCriteria::is_profit_passed(const PeriodData &pdata){
   bool is_passed;
   is_passed = pdata.profit>=min_profit_usd;
   return is_passed;
}

double PropChallengeCriteria::get_current_period_profit(void){
   double prof = 0;
   int ndata = ArraySize(period_data);
   if(ndata>0){
      prof = period_data[ndata-1].profit;
   }
   return prof;
}

double PropChallengeCriteria::get_current_period_drawdown(void){
   double dd = 0;
   int ndata = ArraySize(period_data);
   if(ndata>0){
      dd = period_data[ndata-1].profit_min;
   }
   return dd;
}

bool PropChallengeCriteria::is_current_period_drawdown_passed(void){
   bool is_passed = false;
   int ndata = ArraySize(period_data);
   if(ndata>0){
      is_passed = is_drawdown_passed(period_data[ndata-1]);
   }
   return is_passed;
}

bool PropChallengeCriteria::is_current_period_profit_passed(void){
   bool is_passed = false;
   int ndata = ArraySize(period_data);
   if(ndata>0){
      is_passed = is_profit_passed(period_data[ndata-1]);
   }
   return is_passed;
}

bool PropChallengeCriteria::is_period_passed(const PeriodData &pdata){
   bool is_passed;
   is_passed = is_profit_passed(pdata) && is_drawdown_passed(pdata);
   return is_passed;
}

bool PropChallengeCriteria::is_current_period_passed(void){
   bool is_passed = false;
   int ndata = ArraySize(period_data);
   if(ndata>0){
      is_passed = is_period_passed(period_data[ndata-1]);
   }
   return is_passed;
}

double PropChallengeCriteria::get_results(datetime& passed_periods[]){
   int ndata = ArraySize(period_data);
   double score=0;
   for(int i=0;i<ndata;i++){
      if(is_period_passed(period_data[i])){
         score++;
         int n = ArraySize(passed_periods);
         ArrayResize(passed_periods, n+1);
         passed_periods[n] = period_data[i].datetime_start;
      }
   }
   score /= ndata;
   return score;
}

double PropChallengeCriteria::get_today_profit(void){
   PeriodData pdata = PeriodData(magic_number, 1);
   pdata.update();
   return pdata.profit;
}

double print_prop_challenge_report(double min_profit_usd, double max_drawdown_usd, double daily_loss_limit_usd, int max_allowed_days){
   int results[];  // number of element=number of prop challenges,  -1: failure, 0: neutral(retake), 1:win
   HistorySelect(0, TimeCurrent()+10);
   int ndeals = HistoryDealsTotal();
   double prof = 0;
   double prof_max = 0;
   double prof_min = 0;
   vector<double> prof_daily=vector::Zeros(0);
   datetime start_date = 0;
   MqlDateTime today;
   bool new_challenge = true;
   for(int i=1;i<ndeals;i++){
      if(new_challenge){
         ArrayResize(results, ArraySize(results)+1);
         results[ArraySize(results)-1] = 0;
         prof = 0;
         prof_daily.Resize(prof_daily.Size()+1);
         prof_daily[prof_daily.Size()-1] = 0;
         start_date = (datetime)HistoryDealGetInteger(HistoryDealGetTicket(i), DEAL_TIME);
         TimeToStruct(start_date, today);
         new_challenge = false;
      }
      ulong dealticket = HistoryDealGetTicket(i);
      double p = HistoryDealGetDouble(dealticket, DEAL_PROFIT) + HistoryDealGetDouble(dealticket, DEAL_COMMISSION) + HistoryDealGetDouble(dealticket, DEAL_FEE) + HistoryDealGetDouble(dealticket, DEAL_SWAP);
      datetime current_date = (datetime)HistoryDealGetInteger(HistoryDealGetTicket(i), DEAL_TIME);
      MqlDateTime _today;
      TimeToStruct(current_date, _today);
      if(today.day != _today.day){
         today = _today;
         prof_daily.Resize(prof_daily.Size()+1);
         prof_daily[prof_daily.Size()-1] = 0;
      }
      prof += p;
      prof_daily[prof_daily.Size()-1] += p;
      if(prof>prof_max) prof_max = prof;
      if(prof<prof_min) prof_min = prof;  
      if(prof<=-max_drawdown_usd || prof_daily[prof_daily.Size()-1]<=-daily_loss_limit_usd){
         results[ArraySize(results)-1] = -1;
         new_challenge = true;
      }else if(prof>=min_profit_usd){
         results[ArraySize(results)-1] = 1;
         new_challenge = true;
      }else if(float(current_date-start_date)/PeriodSeconds(PERIOD_D1)>max_allowed_days){
         if(prof<0) results[ArraySize(results)-1] = -1;
         new_challenge = true;
      }
   }
   double all = ArraySize(results);
   double wins = 0;
   double retakes = 0;
   double failures = 0;
   vector<double> consecutive_wins=vector::Zeros(0);
   vector<double> consecutive_failures=vector::Zeros(0);
   vector<double> consecutive_retakes=vector::Zeros(0);
   bool new_round;
   for(int i=0;i<all;i++){
      if(i==0) new_round=true;
      else new_round=results[i]!=results[i-1];
      if(results[i]==-1){
         failures++;
         int last_index = (int)consecutive_failures.Size()-1;
         if(new_round){
            consecutive_failures.Resize(last_index+2);
            last_index = (int)consecutive_failures.Size()-1;
            consecutive_failures[last_index] = 0;
         }
         consecutive_failures[last_index]++;
      }
      else if(results[i]==0){
         retakes++;
         int last_index = (int)consecutive_retakes.Size()-1;
         if(new_round){
            consecutive_retakes.Resize(last_index+2);
            last_index = (int)consecutive_retakes.Size()-1;
            consecutive_retakes[last_index] = 0;
         }
         consecutive_retakes[last_index]++;      
      }
      else if(results[i]==1){
         wins++;
         int last_index = (int)consecutive_wins.Size()-1;
         if(new_round){
            consecutive_wins.Resize(last_index+2);
            last_index = (int)consecutive_wins.Size()-1;
            consecutive_wins[last_index] = 0;
         }
         consecutive_wins[last_index]++;
      }
   }
   Print("-------------Prop challenge report-------------");
   PrintFormat("Min profit (daily): %.0f $", prof_daily.Min());
   PrintFormat("Max profit (daily): %.0f $", prof_daily.Max());
   PrintFormat("Avg profit (daily): %.0f $", prof_daily.Mean());
   PrintFormat("Min prop profit:    %.0f $", prof_min);
   PrintFormat("Max prop profit:    %.0f $", prof_max);
   Print("----------------");
   Print("                         <<<<<<consecutive>>>>>>");
   PrintFormat("         Count    Rate    Max    Avg    Median");
   PrintFormat("wins:    %3.0f       %2.0f%%     %2.0f     %2.0f      %2.0f", wins, 100*wins/all, consecutive_wins.Max(), consecutive_wins.Mean(), consecutive_wins.Median());
   PrintFormat("fails:   %3.0f       %2.0f%%     %2.0f     %2.0f      %2.0f", failures, 100*failures/all, consecutive_failures.Max(), consecutive_failures.Mean(), consecutive_failures.Median());
   PrintFormat("retakes: %3.0f       %2.0f%%     %2.0f     %2.0f      %2.0f", retakes, 100*retakes/all, consecutive_retakes.Max(), consecutive_retakes.Mean(), consecutive_retakes.Median());
   PrintFormat("all:     %3.0f", all);


   Print("---------------------------");
   if(all==0) return 0;
   return NormalizeDouble(100*wins/all, 2);
}