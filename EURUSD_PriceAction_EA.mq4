//+------------------------------------------------------------------+
//|                                         EURUSD_PriceAction_EA.mq4 |
//|                                       Copyright 2023, EA Developer |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, EA Developer"
#property link      ""
#property version   "1.00"
#property strict

// Input Parameters
input double LotSize = 0.01;              // Trading lot size
input int TakeProfit = 60;                // Take profit in pips
input int StopLoss = 30;                  // Stop loss in pips
input int TrailingStart = 30;             // Start trailing after X pips profit
input int TrailingStep = 15;              // Trailing step in pips
input int MaxOpenTrades = 3;              // Maximum number of open trades
input bool EnableNewsFilter = true;       // Enable news filter
input int NewsFilterMinutes = 30;         // Minutes before/after news to avoid trading
input bool EnableLondonSession = true;    // Enable trading during London session
input bool EnableNewYorkSession = true;   // Enable trading during New York session
input int LondonOpenHour = 8;             // London session open hour (GMT)
input int LondonCloseHour = 16;           // London session close hour (GMT)
input int NewYorkOpenHour = 13;           // New York session open hour (GMT)
input int NewYorkCloseHour = 21;          // New York session close hour (GMT)
input int RSI_Period = 14;                // RSI period
input int RSI_Oversold = 30;              // RSI oversold level
input int RSI_Overbought = 70;            // RSI overbought level
input int EMA_Fast_Period = 50;           // Fast EMA period
input int EMA_Slow_Period = 200;          // Slow EMA period
input int ADX_Period = 14;                // ADX period
input int ADX_Threshold = 25;             // ADX threshold for trend strength
input double MaxSpread = 3.0;             // Maximum allowed spread in pips
input bool EnableSRFilter = true;         // Enable support/resistance filter
input int SR_Period = 20;                 // Period for S/R calculation
input double SR_Distance = 20;            // Minimum distance from S/R in pips
input bool EnableMACDFilter = false;      // Enable MACD confirmation
input int MACD_Fast = 12;                 // MACD fast EMA
input int MACD_Slow = 26;                 // MACD slow EMA
input int MACD_Signal = 9;                // MACD signal period

// Global Variables
double g_point;
int g_digits;
double g_pipValue;
datetime g_lastTradeTime = 0;
datetime g_lastBarTime = 0;
int g_totalTrades = 0;
double g_dailyProfit = 0;
double g_currentDrawdown = 0;
double g_accountBalance = 0;
double g_supportLevel = 0;
double g_resistanceLevel = 0;

// Display panel variables
string g_panelName = "EA_InfoPanel";
color g_textColor = clrWhite;
color g_profitColor = clrLime;
color g_lossColor = clrRed;
color g_panelColor = clrNavy;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set up point value based on digits
   g_digits = Digits;
   if(g_digits == 3 || g_digits == 5)
      g_point = Point * 10;
   else
      g_point = Point;
   
   g_pipValue = g_point;  // Corrected pip value calculation
   
   // Initialize account balance
   g_accountBalance = AccountBalance();
   
   // Create display panel
   CreatePanel();
   
   // Calculate initial support and resistance levels
   if(EnableSRFilter)
   {
      CalculateSupportResistance();
   }
   
   Print("EURUSD Price Action EA initialized. Point value: ", g_point, ", Pip value: ", g_pipValue);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Remove display panel
   ObjectDelete(g_panelName);
   
   // Clean up any other objects
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
   {
      string objName = ObjectName(i);
      if(StringFind(objName, "EA_") == 0)
         ObjectDelete(objName);
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update panel on every tick
   UpdatePanel();
   
   // Check if a new bar has formed
   if(IsNewBar())
   {
      // Calculate daily profit/loss
      CalculateDailyProfitLoss();
      
      // Calculate current drawdown
      CalculateDrawdown();
      
      // Update support and resistance levels
      if(EnableSRFilter)
      {
         CalculateSupportResistance();
      }
      
      // Check for trade management (trailing stops, breakeven)
      ManageOpenTrades();
      
      // Check if we can open new trades
      if(CanOpenNewTrade())
      {
         // Check for entry signals
         CheckForEntrySignals();
      }
   }
}

//+------------------------------------------------------------------+
//| Check if a new bar has formed                                    |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(Symbol(), PERIOD_H1, 0);
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if we can open a new trade                                 |
//+------------------------------------------------------------------+
bool CanOpenNewTrade()
{
   // Check if maximum number of trades is reached
   if(CountOpenTrades() >= MaxOpenTrades)
      return false;
   
   // Check if spread is too high
   double currentSpread = MarketInfo(Symbol(), MODE_SPREAD) * Point / g_point;
   if(currentSpread > MaxSpread)
   {
      Print("Spread too high: ", currentSpread, " pips. Max allowed: ", MaxSpread, " pips");
      return false;
   }
   
   // Check if we're in allowed trading sessions
   if(!IsAllowedTradingSession())
      return false;
   
   // Check if we're in news filter period
   if(EnableNewsFilter && IsNewsTime())
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Count open trades for this EA                                    |
//+------------------------------------------------------------------+
int CountOpenTrades()
{
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == 12345)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if current time is within allowed trading sessions         |
//+------------------------------------------------------------------+
bool IsAllowedTradingSession()
{
   int currentHour = TimeHour(TimeCurrent());
   
   bool londonSession = (currentHour >= LondonOpenHour && currentHour < LondonCloseHour);
   bool newYorkSession = (currentHour >= NewYorkOpenHour && currentHour < NewYorkCloseHour);
   
   if(EnableLondonSession && londonSession)
      return true;
   
   if(EnableNewYorkSession && newYorkSession)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if current time is near high-impact news                   |
//+------------------------------------------------------------------+
bool IsNewsTime()
{
   // This is a placeholder for a news filter
   // In a real implementation, you would connect to a news calendar API
   // or use a pre-defined news schedule file
   
   // For demonstration purposes, we'll just return false
   return false;
}

//+------------------------------------------------------------------+
//| Calculate support and resistance levels                          |
//+------------------------------------------------------------------+
void CalculateSupportResistance()
{
   double highestHigh = 0;
   double lowestLow = 100000;
   
   // Find highest high and lowest low over SR_Period
   for(int i = 1; i <= SR_Period; i++)
   {
      double high = iHigh(Symbol(), PERIOD_H1, i);
      double low = iLow(Symbol(), PERIOD_H1, i);
      
      if(high > highestHigh)
         highestHigh = high;
      
      if(low < lowestLow)
         lowestLow = low;
   }
   
   g_resistanceLevel = highestHigh;
   g_supportLevel = lowestLow;
}

//+------------------------------------------------------------------+
//| Check if price is near support or resistance                     |
//+------------------------------------------------------------------+
bool IsPriceNearSR(double price, int direction)
{
   if(!EnableSRFilter)
      return false;
   
   double distanceToResistance = MathAbs(g_resistanceLevel - price) / g_pipValue;
   double distanceToSupport = MathAbs(price - g_supportLevel) / g_pipValue;
   
   // For buy orders, check if too close to resistance
   if(direction == OP_BUY && distanceToResistance < SR_Distance)
      return true;
   
   // For sell orders, check if too close to support
   if(direction == OP_SELL && distanceToSupport < SR_Distance)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for entry signals                                          |
//+------------------------------------------------------------------+
void CheckForEntrySignals()
{
   // Check for Pin Bar pattern
   bool buyPinBar = IsBuyPinBar();
   bool sellPinBar = IsSellPinBar();
   
   // Check for Engulfing pattern
   bool buyEngulfing = IsBuyEngulfing();
   bool sellEngulfing = IsSellEngulfing();
   
   // Check for Breakout with retest
   bool buyBreakout = IsBuyBreakout();
   bool sellBreakout = IsSellBreakout();
   
   // Check RSI filter
   double rsi = iRSI(Symbol(), PERIOD_H1, RSI_Period, PRICE_CLOSE, 1);
   bool rsiBuyOK = (rsi < RSI_Oversold);
   bool rsiSellOK = (rsi > RSI_Overbought);
   
   // Check EMA trend filter
   double emaFast = iMA(Symbol(), PERIOD_H1, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), PERIOD_H1, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
   bool emaBuyOK = (emaFast > emaSlow);
   bool emaSellOK = (emaFast < emaSlow);
   
   // Check ADX filter
   double adx = iADX(Symbol(), PERIOD_H1, ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
   bool adxOK = (adx > ADX_Threshold);
   
   // Check volume filter
   bool volumeIncreasing = IsVolumeIncreasing();
   
   // Check MACD filter if enabled
   bool macdBuyOK = true;
   bool macdSellOK = true;
   
   if(EnableMACDFilter)
   {
      double macdMain, macdSignal, macdMainPrev, macdSignalPrev;
      
      macdMain = iMACD(Symbol(), PERIOD_H1, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_MAIN, 1);
      macdSignal = iMACD(Symbol(), PERIOD_H1, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_SIGNAL, 1);
      macdMainPrev = iMACD(Symbol(), PERIOD_H1, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_MAIN, 2);
      macdSignalPrev = iMACD(Symbol(), PERIOD_H1, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE, MODE_SIGNAL, 2);
      
      macdBuyOK = (macdMain > macdSignal && macdMainPrev <= macdSignalPrev);
      macdSellOK = (macdMain < macdSignal && macdMainPrev >= macdSignalPrev);
   }
   
   // BUY SIGNAL
   if((buyPinBar || buyEngulfing || buyBreakout) && rsiBuyOK && emaBuyOK && adxOK && volumeIncreasing && macdBuyOK)
   {
      if(!IsPriceNearSR(Ask, OP_BUY))
      {
         OpenTrade(OP_BUY);
      }
   }
   
   // SELL SIGNAL
   if((sellPinBar || sellEngulfing || sellBreakout) && rsiSellOK && emaSellOK && adxOK && volumeIncreasing && macdSellOK)
   {
      if(!IsPriceNearSR(Bid, OP_SELL))
      {
         OpenTrade(OP_SELL);
      }
   }
}

//+------------------------------------------------------------------+
//| Check for Pin Bar pattern                                        |
//+------------------------------------------------------------------+
bool IsBuyPinBar()
{
   double open1 = iOpen(Symbol(), PERIOD_H1, 1);
   double close1 = iClose(Symbol(), PERIOD_H1, 1);
   double high1 = iHigh(Symbol(), PERIOD_H1, 1);
   double low1 = iLow(Symbol(), PERIOD_H1, 1);
   
   // Calculate body and tails
   double body = MathAbs(open1 - close1);
   double upperTail = high1 - MathMax(open1, close1);
   double lowerTail = MathMin(open1, close1) - low1;
   
   // Buy Pin Bar: long lower tail, small body, small upper tail
   if(lowerTail > 2.5 * body && lowerTail > 2 * upperTail && body > 0)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for Sell Pin Bar pattern                                   |
//+------------------------------------------------------------------+
bool IsSellPinBar()
{
   double open1 = iOpen(Symbol(), PERIOD_H1, 1);
   double close1 = iClose(Symbol(), PERIOD_H1, 1);
   double high1 = iHigh(Symbol(), PERIOD_H1, 1);
   double low1 = iLow(Symbol(), PERIOD_H1, 1);
   
   // Calculate body and tails
   double body = MathAbs(open1 - close1);
   double upperTail = high1 - MathMax(open1, close1);
   double lowerTail = MathMin(open1, close1) - low1;
   
   // Sell Pin Bar: long upper tail, small body, small lower tail
   if(upperTail > 2.5 * body && upperTail > 2 * lowerTail && body > 0)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for Bullish Engulfing pattern                              |
//+------------------------------------------------------------------+
bool IsBuyEngulfing()
{
   double open1 = iOpen(Symbol(), PERIOD_H1, 1);
   double close1 = iClose(Symbol(), PERIOD_H1, 1);
   double open2 = iOpen(Symbol(), PERIOD_H1, 2);
   double close2 = iClose(Symbol(), PERIOD_H1, 2);
   
   // Bullish Engulfing: previous candle bearish, current candle bullish and engulfs previous
   if(close2 < open2 && close1 > open1 && close1 > open2 && open1 < close2)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for Bearish Engulfing pattern                              |
//+------------------------------------------------------------------+
bool IsSellEngulfing()
{
   double open1 = iOpen(Symbol(), PERIOD_H1, 1);
   double close1 = iClose(Symbol(), PERIOD_H1, 1);
   double open2 = iOpen(Symbol(), PERIOD_H1, 2);
   double close2 = iClose(Symbol(), PERIOD_H1, 2);
   
   // Bearish Engulfing: previous candle bullish, current candle bearish and engulfs previous
   if(close2 > open2 && close1 < open1 && close1 < open2 && open1 > close2)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for Bullish Breakout with retest                           |
//+------------------------------------------------------------------+
bool IsBuyBreakout()
{
   // Find recent resistance level (simplified)
   double resistance = 0;
   for(int i = 2; i < 20; i++)
   {
      double high = iHigh(Symbol(), PERIOD_H1, i);
      if(high > resistance)
         resistance = high;
   }
   
   // Check if previous candle broke above resistance
   double high1 = iHigh(Symbol(), PERIOD_H1, 1);
   double close1 = iClose(Symbol(), PERIOD_H1, 1);
   double low1 = iLow(Symbol(), PERIOD_H1, 1);
   
   // Breakout with retest: price broke above resistance and retested it
   if(high1 > resistance && low1 <= resistance && close1 > resistance)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for Bearish Breakout with retest                           |
//+------------------------------------------------------------------+
bool IsSellBreakout()
{
   // Find recent support level (simplified)
   double support = 100000;
   for(int i = 2; i < 20; i++)
   {
      double low = iLow(Symbol(), PERIOD_H1, i);
      if(low < support)
         support = low;
   }
   
   // Check if previous candle broke below support
   double low1 = iLow(Symbol(), PERIOD_H1, 1);
   double close1 = iClose(Symbol(), PERIOD_H1, 1);
   double high1 = iHigh(Symbol(), PERIOD_H1, 1);
   
   // Breakout with retest: price broke below support and retested it
   if(low1 < support && high1 >= support && close1 < support)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if volume is increasing                                    |
//+------------------------------------------------------------------+
bool IsVolumeIncreasing()
{
   double volume1 = iVolume(Symbol(), PERIOD_H1, 1);
   double volume2 = iVolume(Symbol(), PERIOD_H1, 2);
   double volume3 = iVolume(Symbol(), PERIOD_H1, 3);
   
   // Volume is increasing if current volume is higher than average of previous 2
   double avgVolume = (volume2 + volume3) / 2;
   if(volume1 > avgVolume)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Open a new trade                                                 |
//+------------------------------------------------------------------+
void OpenTrade(int tradeType)
{
   double price, stopLoss, takeProfit;
   string comment;
   color arrowColor;
   
   // Set trade parameters based on trade type
   if(tradeType == OP_BUY)
   {
      price = Ask;
      stopLoss = price - StopLoss * g_pipValue;
      takeProfit = price + TakeProfit * g_pipValue;
      comment = "EURUSD PA EA Buy";
      arrowColor = clrBlue;
   }
   else // OP_SELL
   {
      price = Bid;
      stopLoss = price + StopLoss * g_pipValue;
      takeProfit = price - TakeProfit * g_pipValue;
      comment = "EURUSD PA EA Sell";
      arrowColor = clrRed;
   }
   
   // Open the trade
   int ticket = OrderSend(Symbol(), tradeType, LotSize, price, 3, stopLoss, takeProfit, comment, 12345, 0, arrowColor);
   
   if(ticket > 0)
   {
      g_lastTradeTime = TimeCurrent();
      g_totalTrades++;
      
      // Send notification
      string tradeTypeStr = (tradeType == OP_BUY) ? "BUY" : "SELL";
      string message = "EURUSD PA EA: New " + tradeTypeStr + " trade opened at " + DoubleToStr(price, 5);
      SendNotification(message);
      
      Print("Trade opened: ", tradeTypeStr, " at ", price, ", SL: ", stopLoss, ", TP: ", takeProfit);
   }
   else
   {
      int errorCode = GetLastError();
      Print("Error opening trade: ", ErrorMsg(errorCode), " (", errorCode, ")");
   }
}

//+------------------------------------------------------------------+
//| Custom function to return error message                          |
//+------------------------------------------------------------------+
string ErrorMsg(int error_code)
{
   string error_string;
   
   switch(error_code)
   {
      case 0:   error_string = "No error";                                                   break;
      case 1:   error_string = "No error, but the result is unknown";                        break;
      case 2:   error_string = "Common error";                                               break;
      case 3:   error_string = "Invalid trade parameters";                                   break;
      case 4:   error_string = "Trade server is busy";                                       break;
      case 5:   error_string = "Old version of the client terminal";                         break;
      case 6:   error_string = "No connection with trade server";                            break;
      case 7:   error_string = "Not enough rights";                                          break;
      case 8:   error_string = "Too frequent requests";                                      break;
      case 9:   error_string = "Malfunctional trade operation";                              break;
      case 64:  error_string = "Account disabled";                                           break;
      case 65:  error_string = "Invalid account";                                            break;
      case 128: error_string = "Trade timeout";                                              break;
      case 129: error_string = "Invalid price";                                              break;
      case 130: error_string = "Invalid stops";                                              break;
      case 131: error_string = "Invalid trade volume";                                       break;
      case 132: error_string = "Market is closed";                                           break;
      case 133: error_string = "Trade is disabled";                                          break;
      case 134: error_string = "Not enough money";                                           break;
      case 135: error_string = "Price changed";                                              break;
      case 136: error_string = "Off quotes";                                                 break;
      case 137: error_string = "Broker is busy";                                             break;
      case 138: error_string = "Requote";                                                    break;
      case 139: error_string = "Order is locked";                                            break;
      case 140: error_string = "Long positions only allowed";                                break;
      case 141: error_string = "Too many requests";                                          break;
      case 145: error_string = "Modification denied because order is too close to market";   break;
      case 146: error_string = "Trade context is busy";                                      break;
      case 147: error_string = "Expirations are denied by broker";                           break;
      case 148: error_string = "Amount of open and pending orders has reached the limit";    break;
      case 149: error_string = "Hedging is prohibited";                                      break;
      case 150: error_string = "Prohibited by FIFO rules";                                   break;
      default:  error_string = "Unknown error";
   }
   
   return(error_string);
}

//+------------------------------------------------------------------+
//| Manage open trades (trailing stop, breakeven)                    |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == 12345)
         {
            // Calculate current profit in pips
            double currentProfit = 0;
            if(OrderType() == OP_BUY)
               currentProfit = (Bid - OrderOpenPrice()) / g_pipValue;
            else if(OrderType() == OP_SELL)
               currentProfit = (OrderOpenPrice() - Ask) / g_pipValue;
            
            // Move to breakeven
            if(currentProfit >= TrailingStart && OrderStopLoss() != OrderOpenPrice())
            {
               double newStopLoss = OrderOpenPrice();
               bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrYellow);
               
               if(modified)
               {
                  Print("Trade #", OrderTicket(), " moved to breakeven");
                  SendNotification("EURUSD PA EA: Trade #" + IntegerToString(OrderTicket()) + " moved to breakeven");
               }
            }
            
            // Apply trailing stop
            if(currentProfit >= TrailingStart + TrailingStep)
            {
               double newStopLoss = 0;
               
               if(OrderType() == OP_BUY)
               {
                  newStopLoss = Bid - TrailingStep * g_pipValue;
                  if(newStopLoss > OrderStopLoss())
                  {
                     bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrYellow);
                     
                     if(modified)
                     {
                        // Fix for type conversion warnings - use proper precision value
                        int precision = _Digits; // Use built-in _Digits instead of g_digits
                        string stopLossStr = DoubleToStr(newStopLoss, precision);
                        Print("Trailing stop updated for trade #", OrderTicket(), " to ", stopLossStr);
                        SendNotification("EURUSD PA EA: Trailing stop updated for trade #" + IntegerToString(OrderTicket()));
                     }
                  }
               }
               else if(OrderType() == OP_SELL)
               {
                  newStopLoss = Ask + TrailingStep * g_pipValue;
                  if(newStopLoss < OrderStopLoss() || OrderStopLoss() == 0)
                  {
                     bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrYellow);
                     
                     if(modified)
                     {
                        // Fix for type conversion warnings - use proper precision value
                        int precision = _Digits; // Use built-in _Digits instead of g_digits
                        string stopLossStr = DoubleToStr(newStopLoss, precision);
                        Print("Trailing stop updated for trade #", OrderTicket(), " to ", stopLossStr);
                        SendNotification("EURUSD PA EA: Trailing stop updated for trade #" + IntegerToString(OrderTicket()));
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate daily profit/loss                                      |
//+------------------------------------------------------------------+
void CalculateDailyProfitLoss()
{
   datetime today = TimeCurrent();
   datetime dayStart = StrToTime(TimeToStr(today, TIME_DATE));
   
   g_dailyProfit = 0;
   
   // Check closed orders for today
   for(int i = 0; i < OrdersHistoryTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == 12345 && OrderCloseTime() >= dayStart)
         {
            g_dailyProfit += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
   }
   
   // Add unrealized profit from open orders
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == 12345)
         {
            g_dailyProfit += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate current drawdown                                       |
//+------------------------------------------------------------------+
void CalculateDrawdown()
{
   double currentEquity = AccountEquity();
   double maxEquity = MathMax(g_accountBalance, currentEquity);
   
   if(maxEquity > g_accountBalance)
      g_accountBalance = maxEquity;
   
   if(g_accountBalance > 0)
      g_currentDrawdown = (g_accountBalance - currentEquity) / g_accountBalance * 100;
   else
      g_currentDrawdown = 0;
}

//+------------------------------------------------------------------+
//| Create information panel on chart                                |
//+------------------------------------------------------------------+
void CreatePanel()
{
   // Create panel background
   ObjectCreate(g_panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSet(g_panelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSet(g_panelName, OBJPROP_XDISTANCE, 10);
   ObjectSet(g_panelName, OBJPROP_YDISTANCE, 10);
   ObjectSet(g_panelName, OBJPROP_XSIZE, 200);
   ObjectSet(g_panelName, OBJPROP_YSIZE, 120);
   ObjectSet(g_panelName, OBJPROP_BGCOLOR, g_panelColor);
   ObjectSet(g_panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSet(g_panelName, OBJPROP_COLOR, clrWhite);
   ObjectSet(g_panelName, OBJPROP_WIDTH, 1);
   ObjectSet(g_panelName, OBJPROP_BACK, false);
   
   // Create labels
   CreatePanelLabel("EA_Title", "EURUSD Price Action EA", 20, 20, clrYellow, 10);
   CreatePanelLabel("EA_OpenTrades", "Open Trades: 0", 20, 40, g_textColor, 9);
   CreatePanelLabel("EA_Drawdown", "Drawdown: 0.00%", 20, 60, g_textColor, 9);
   CreatePanelLabel("EA_DailyPL", "Daily P/L: $0.00", 20, 80, g_textColor, 9);
   CreatePanelLabel("EA_Spread", "Current Spread: 0.0 pips", 20, 100, g_textColor, 9);
}

//+------------------------------------------------------------------+
//| Create a label for the panel                                     |
//+------------------------------------------------------------------+
void CreatePanelLabel(string name, string text, int x, int y, color textColor, int fontSize)
{
   ObjectCreate(name, OBJ_LABEL, 0, 0, 0);
   ObjectSet(name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSet(name, OBJPROP_XDISTANCE, x);
   ObjectSet(name, OBJPROP_YDISTANCE, y);
   ObjectSetText(name, text, fontSize, "Arial", textColor);
}

//+------------------------------------------------------------------+
//| Update information panel on chart                                |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   int openTrades = CountOpenTrades();
   double currentSpread = MarketInfo(Symbol(), MODE_SPREAD) * Point / g_point;
   
   ObjectSetText("EA_OpenTrades", "Open Trades: " + IntegerToString(openTrades), 9, "Arial", g_textColor);
   ObjectSetText("EA_Drawdown", "Drawdown: " + DoubleToString(g_currentDrawdown, 2) + "%", 9, "Arial", g_textColor);
   
   color plColor = (g_dailyProfit >= 0) ? g_profitColor : g_lossColor;
   ObjectSetText("EA_DailyPL", "Daily P/L: $" + DoubleToString(g_dailyProfit, 2), 9, "Arial", plColor);
   
   color spreadColor = (currentSpread <= MaxSpread) ? g_textColor : g_lossColor;
   ObjectSetText("EA_Spread", "Current Spread: " + DoubleToString(currentSpread, 1) + " pips", 9, "Arial", spreadColor);
}
