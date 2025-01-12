
getwd()
setwd("C:\\Users\\bida22-068\\Downloads\\R Assignment")
list.files()

#Loading Libraries
library(tidyverse)
library(readxl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(plotly)

#Loading dataset
Gemini <- read.csv("gemini_LTCUSD_2020_1min.csv")
# view(Gemini)

# Exploring the data
names(Gemini)
glimpse(Gemini)
dim(Gemini)
head(Gemini)
summary(Gemini)

missing_values <- colSums(is.na(Gemini))
print(missing_values)

# Visualize potential outliers in numeric columns
Gemini %>%
  gather(key = "Variable", value = "Value", Open:Volume) %>%
  ggplot(aes(x = Variable, y = Value)) +
  geom_boxplot() +
  labs(title = "Boxplots for Numeric Variables") +
  theme_minimal()

Gemini_clean <- Gemini
names(Gemini_clean)

# Check unique values in the Symbol column
unique_symbols <- unique(Gemini$Symbol)
print(unique_symbols)
Gemini_clean <- Gemini %>% select(-Symbol)

# Correcting Unix timestamp format and converting to DateTime
# First, ensure that the timestamp is treated as numeric
Gemini_clean$Unix.Timestamp <- as.numeric(Gemini_clean$Unix.Timestamp)

# Convert Unix timestamp to a readable date-time format
Gemini_clean <- Gemini_clean %>%
  mutate(DateTime = as.POSIXct(Unix.Timestamp / 1000, origin = "1970-01-01", tz = "UTC"))
head(Gemini_clean)

summary(Gemini_clean)

# Custom Winsorization function
winsorize_manual <- function(x, lower_prob = 0.025, upper_prob = 0.975) {
  lower_bound <- quantile(x, probs = lower_prob, na.rm = TRUE)
  upper_bound <- quantile(x, probs = upper_prob, na.rm = TRUE)
  x_winsorized <- pmin(pmax(x, lower_bound), upper_bound)  # Cap values
  return(x_winsorized)
}

# winsorization probabilities
winsorization_probs <- list(
  Open = c(0.025, 0.975),
  High = c(0.025, 0.975),
  Low = c(0.025, 0.975),
  Close = c(0.025, 0.975),
  Volume = c(0.01, 0.99)  # Higher probability for Volume
)

# Apply tailored winsorization using the custom function
Gemini_winsorized <- Gemini_clean %>%
  mutate(
    Open = winsorize_manual(Open, winsorization_probs$Open[1], winsorization_probs$Open[2]),
    High = winsorize_manual(High, winsorization_probs$High[1], winsorization_probs$High[2]),
    Low = winsorize_manual(Low, winsorization_probs$Low[1], winsorization_probs$Low[2]),
    Close = winsorize_manual(Close, winsorization_probs$Close[1], winsorization_probs$Close[2]),
    Volume = winsorize_manual(Volume, winsorization_probs$Volume[1], winsorization_probs$Volume[2])
  )

# Check summary to confirm winsorization results
summary(Gemini_winsorized)

# Visualizing boxplots after adjustments
Gemini_winsorized %>%
  pivot_longer(cols = c(Open, High, Low, Close, Volume), names_to = "Variable", values_to = "Value") %>%
  ggplot(aes(x = Variable, y = Value)) +
  geom_boxplot() +
  labs(title = "Boxplots After Winsorization") +
  theme_minimal()

# Count the number of zero values in the Volume column after winsorization
zero_count <- sum(Gemini_winsorized$Volume == 0)
print(zero_count)

total_count <- nrow(Gemini_winsorized)
proportion_zeros <- zero_count / total_count
print(proportion_zeros)

# Display the proportion as a percentage
cat("Proportion of zero values in Volume: ", proportion_zeros * 100, "%\n")


Gemini_winsorized <- Gemini_winsorized[Gemini_winsorized$Volume > 0, ]

ggplot(Gemini_winsorized, aes(x = Volume)) +
  geom_histogram(bins = 30, fill = "blue", color = "black", alpha = 0.7) +
  labs(title = "Histogram of Volume (After Removing Zeros)", x = "Volume", y = "Frequency") +
  theme_minimal()

# Apply square root transformation to the original Volume (before log transformation)
Gemini_winsorized <- Gemini_winsorized %>%
  mutate(Sqrt_Volume = sqrt(Volume))

# Visualize the square root transformed Volume
ggplot(Gemini_winsorized, aes(x = Sqrt_Volume)) +
  geom_histogram(bins = 30, fill = "blue", color = "black", alpha = 0.7) +
  labs(title = "Histogram of Square Root Transformed Volume", 
       x = "Square Root Transformed Volume", 
       y = "Frequency") +
  theme_minimal()

# Histogram of Open, High, Low, Close, and Volume
Gemini_winsorized %>%
  pivot_longer(cols = c(Open, High, Low, Close, Sqrt_Volume), names_to = "Variable", values_to = "Value") %>%
  ggplot(aes(x = Value, fill = Variable)) +
  geom_histogram(bins = 30, color = "black", alpha = 0.8) +
  facet_wrap(~ Variable, scales = "free") +
  labs(title = "Distribution of Key Variables", x = "Value", y = "Frequency") +
  theme_minimal() +
  scale_fill_manual(values = c("Open" = "green", "High" = "orange", "Low" = "purple", 
                               "Close" = "blue", "Volume" = "red"))


summary(Gemini_winsorized$Volume)

# Check if there are any missing or non-numeric values in the price columns in Gemini_winsorized


# Scatterplot of Open vs Close prices
scatter_plot <- ggplot(Gemini_winsorized, aes(x = Open, y = Close)) +
  geom_point(alpha = 0.6, color = "blue") +
  labs(title = "Scatterplot of Open vs Close Prices",
       x = "Open Price",
       y = "Close Price") +
  theme_minimal() +
  geom_smooth(method = "lm", color = "red", se = FALSE)

# Convert to interactive plot with plotly
ggplotly(scatter_plot)

# Summarizing Volume by Month
Gemini_winsorized$Month <- format(Gemini_winsorized$DateTime, "%Y-%m")  # Extract month from DateTime

monthly_volume <- Gemini_winsorized %>%
  group_by(Month) %>%
  summarise(Total_Volume = sum(Volume))

names(Gemini_winsorized)

# Create the bar chart with ggplot2
bar_chart <- ggplot(monthly_volume, aes(x = Month, y = Total_Volume)) +
  geom_bar(stat = "identity", fill = "darkred") +
  labs(title = "Total Trading Volumes Per Month",
       x = "Month",
       y = "Total Volume") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))  # Rotate x-axis labels 

ggplotly(bar_chart, tooltip = c("x", "y"))





# Line chart for Close price over time 
p <- ggplot(Gemini_winsorized, aes(x = as.Date(DateTime), y = Close)) +
  geom_line(color = "green") +
  labs(title = "LTC Close Price Over Time", x = "Date", y = "Close Price (USD)") +
  theme_minimal() +
  scale_x_date(date_labels = "%Y-%m-%d", date_breaks = "1 month") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
p

ggplotly(p, tooltip = c("x", "y"))

# Calculate daily returns 
Gemini_winsorized <- Gemini_winsorized %>%
  mutate(Daily_Return = (Close / lag(Close) - 1) * 100)


# Plot daily returns
ggplot(Gemini_winsorized, aes(x = as.Date(DateTime), y = Daily_Return)) +
  geom_line(color = "blue") +
  labs(title = "Daily Returns of LTC", x = "Date", y = "Daily Return (%)") +
  theme_minimal() +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 month") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

plot_ly(Gemini_winsorized, x = ~as.Date(DateTime), y = ~Daily_Return, type = 'scatter', mode = 'lines', line = list(color = 'blue')) %>%
  layout(title = "Daily Returns of LTC",
         xaxis = list(title = "Date"),
         yaxis = list(title = "Daily Return (%)"),
         hovermode = "closest")


# Calculating Moving Averages for 10, 20, and 50-day windows
library(TTR)  # For calculating moving averages

Gemini_winsorized <- Gemini_winsorized %>%
  mutate(
    MA5 = SMA(Close, n = 5),
    MA10 = SMA(Close, n = 10),
    MA20 = SMA(Close, n = 20),
    MA50 = SMA(Close, n = 50),
    MA100 = SMA(Close, n = 100),
    MA200 = SMA(Close, n = 200)
  )


# Interactive Time series with moving average plot using plotly
# Creating an interactive plot for Close Price with Moving Averages
interactive_ma_plot <- plot_ly(Gemini_winsorized, x = ~DateTime, y = ~Close, name = "Close Price", type = 'scatter', mode = 'lines', line = list(color = 'green')) %>%
  add_trace(y = ~MA5, name = "5-Min MA", mode = 'lines', line = list(color = 'red')) %>%
  add_trace(y = ~MA10, name = "10-Min MA", mode = 'lines', line = list(color = 'blue')) %>%
  add_trace(y = ~MA20, name = "20-Min MA", mode = 'lines', line = list(color = 'orange')) %>%
  add_trace(y = ~MA50, name = "50-Min MA", mode = 'lines', line = list(color = 'purple')) %>%
  add_trace(y = ~MA100, name = "100-Min MA", mode = 'lines', line = list(color = 'brown')) %>%
  add_trace(y = ~MA200, name = "200-Min MA", mode = 'lines', line = list(color = 'pink')) %>%
  layout(title = "LTC Close Price with Moving Averages (Interactive)",
         xaxis = list(title = "Date", rangeslider = list(visible = TRUE)),
         yaxis = list(title = "Price (USD)"),
         hovermode = "x unified",
         legend = list(orientation = "h", x = 0.1, y = 1.1),
         margin = list(t = 100)) %>%
  config(scrollZoom = TRUE)

interactive_ma_plot


library(forecast)
library(ggplot2)

# Aggregate data at the daily level
daily_data <- Gemini_winsorized %>%
  group_by(Date = as.Date(DateTime)) %>%
  summarise(Daily_Close = last(Close), .groups = 'drop')

# Fit an ARIMA model to the daily closing prices
arima_model <- auto.arima(daily_data$Daily_Close)

# Forecast the next 30 days
forecast_arima <- forecast(arima_model, h = 30)

# Convert the forecast to a data frame for plotting
forecast_df <- data.frame(
  Date = seq.Date(max(daily_data$Date) + 1, by = "day", length.out = 30),
  Forecast = forecast_arima$mean,
  Lower = forecast_arima$lower[, 2],
  Upper = forecast_arima$upper[, 2]
)

interactive_plot <- ggplot() +
  geom_line(data = daily_data, aes(x = Date, y = Daily_Close), color = 'blue', size = 1) +  # Historical Data
  geom_line(data = forecast_df, aes(x = Date, y = Forecast), color = 'red', size = 1) +  # Forecast
  geom_ribbon(data = forecast_df, aes(x = Date, ymin = Lower, ymax = Upper), fill = 'red', alpha = 0.2) +  # Confidence Interval
  labs(title = "30-Day Forecast of Daily Close Prices", x = "Date", y = "Close Price (USD)") +
  theme_minimal() +
  scale_x_date(date_labels = "%Y-%m-%d")  # Proper date formatting for x-axis

# Convert the ggplot to an interactive plotly object
ggplotly(interactive_plot) %>%
  layout(legend = list(title = list(text = "Legend")))  # Customize legend if desired


library(shiny)
library(shinydashboard)
library(lubridate)  # For date manipulation
library(forecast)

# Define UI for the dashboard
ui <- dashboardPage(
  dashboardHeader(title = "LTC Data Analysis"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Market Analysis", tabName = "analysis", icon = icon("chart-line")),
      menuItem("Forecast", tabName = "forecast", icon = icon("chart-area")),
      menuItem("About", tabName = "about", icon = icon("info-circle"))
    ),
    dateRangeInput("dateRange", "Date Range:",
                   start = min(Gemini_winsorized$DateTime),
                   end = max(Gemini_winsorized$DateTime),
                   format = "yyyy-mm-dd")
  ),
  dashboardBody(
    tabItems(
      tabItem(tabName = "analysis",
              fluidRow(
                box(title = "LTC Candlestick Chart", status = "primary", solidHeader = TRUE, 
                    plotlyOutput("candlestickPlot")),
                box(title = "Close Price with Moving Averages", status = "primary", solidHeader = TRUE, 
                    plotlyOutput("maPlot")),
                box(title="Volume", status="primary", solidHeader=TRUE,
                    plotlyOutput("volumePlot")),
                box(title="Daily Returns", status="primary", solidHeader=TRUE,
                    plotlyOutput("dailyReturnsPlot"))
              )
      ),
      tabItem(tabName = "forecast",
              fluidRow(
                box(title = "30-Day Forecast of Daily Close Prices", status = "primary", solidHeader = TRUE, 
                    plotlyOutput("forecastPlot"))
              )
      ),
      tabItem(tabName = "about",
              h2("About this Dashboard"),
              p("This dashboard presents an analysis of Litecoin trading data, highlighting price trends, volume activity, return distributions, and technical indicators.")
      )
    )
  )
)

# Define server logic
server <- function(input, output) {
  
  rv <- reactiveValues(data = NULL, daily_data = NULL)
  
  # Reactive data filtered by the date range
  filtered_data <- reactive({
    req(input$dateRange)  # Ensure input$dateRange is available
    Gemini_winsorized %>%
      filter(DateTime >= input$dateRange[1] & DateTime <= input$dateRange[2]) %>%
      mutate(MA5 = zoo::rollmean(Close, 5, fill = NA, align = 'right'),
             MA10 = zoo::rollmean(Close, 10, fill = NA, align = 'right'),
             MA20 = zoo::rollmean(Close, 20, fill = NA, align = 'right'),
             MA50 = zoo::rollmean(Close, 50, fill = NA, align = 'right'),
             MA100 = zoo::rollmean(Close, 100, fill = NA, align = 'right'),
             MA200 = zoo::rollmean(Close, 200, fill = NA, align = 'right')) # Calculate moving averages
  })
  
  # Render candlestick plot
  output$candlestickPlot <- renderPlotly({
    req(filtered_data())  # Ensure filtered data is available
    plot_ly(data = filtered_data(), x = ~DateTime, type = "candlestick",
            open = ~Open, close = ~Close, high = ~High, low = ~Low, name = "Candlestick") %>%
      layout(title = "LTC Candlestick Chart",
             xaxis = list(title = "Date"),
             yaxis = list(title = "Price (USD)"),
             hovermode = "x unified")
  })
  
  # Render moving averages plot
  output$maPlot <- renderPlotly({
    req(filtered_data())  # Ensure filtered data is available
    plot_ly(data = filtered_data(), x = ~DateTime) %>%
      add_trace(y = ~Close, name = "Close Price", type = 'scatter', mode = 'lines', line = list(color = 'green')) %>%
      add_trace(y = ~MA5, name = "5-Day MA", mode = 'lines', line = list(color = 'red')) %>%
      add_trace(y = ~MA10, name = "10-Day MA", mode = 'lines', line = list(color = 'blue')) %>%
      add_trace(y = ~MA20, name = "20-Day MA", mode = 'lines', line = list(color = 'orange')) %>%
      add_trace(y = ~MA50, name = "50-Day MA", mode = 'lines', line = list(color = 'purple')) %>%
      add_trace(y = ~MA100, name = "100-Day MA", mode = 'lines', line = list(color = 'brown')) %>%
      add_trace(y = ~MA200, name = "200-Day MA", mode = 'lines', line = list(color = 'pink')) %>%
      layout(title = "LTC Close Price with Moving Averages",
             xaxis = list(title = "Date"),
             yaxis = list(title = "Price (USD)"),
             hovermode = "x unified",
             legend = list(orientation = "h", x = 0.1, y = 1.1),
             margin = list(t = 100))
  })
  
  # Render volume plot
  output$volumePlot <- renderPlotly({
    req(filtered_data())  # Ensure filtered data is available
    volume_data <- filtered_data() %>%
      group_by(Date = as.Date(DateTime)) %>%
      summarise(Total_Volume = sum(Volume), .groups = 'drop')  # Group by date and sum volume
    plot_ly(data = volume_data, x = ~Date, y = ~Total_Volume, type = 'bar', name = "Total Volume", 
            marker = list(color = 'rgba(0, 150, 136, 0.8)', line = list(color = 'rgba(0, 150, 136, 1)', width = 1))) %>%
      layout(title = "Volume",
             xaxis = list(title = "Date"),
             yaxis = list(title = "Volume"),
             hovermode = "x unified")
  })
  
  # Render daily returns plot
  output$dailyReturnsPlot <- renderPlotly({
    req(filtered_data())  # Ensure filtered data is available
    daily_returns <- filtered_data() %>%
      arrange(DateTime) %>%
      mutate(Daily_Returns = (Close - lag(Close)) / lag(Close) * 100) %>%
      drop_na()  # Remove NA values
    plot_ly(data = daily_returns, x = ~DateTime, y = ~Daily_Returns, type = 'scatter', mode = 'lines', 
            name = "Daily Returns", line = list(color = 'rgba(255, 87, 34, 0.8)', width = 2)) %>%
      layout(title = "Daily Returns",
             xaxis = list(title = "Date"),
             yaxis = list(title = "Return (%)"),
             hovermode = "x unified")
  })
  
  # Render forecast plot
  output$forecastPlot <- renderPlotly({
    # Prepare daily aggregated data for forecasting
    daily_data <- filtered_data() %>%
      mutate(Date = as.Date(DateTime)) %>%
      group_by(Date) %>%
      summarise(Daily_Close = last(na.omit(Close)), .groups = 'drop')  # Ensure no NAs
    
    if (nrow(daily_data) < 30) {
      return(NULL)  # Avoid forecasting if insufficient data
    }
    
    # Convert to a time series object
    ts_data <- ts(daily_data$Daily_Close, frequency = 365)  # Daily frequency assumed
    
    # Apply ARIMA forecasting
    model <- auto.arima(ts_data)
    forecast_result <- forecast(model, h = 30)  # Forecast for 30 days
    
    # Prepare forecast data for plot
    forecast_df <- data.frame(
      Date = seq.Date(from = max(daily_data$Date) + 1, by = "day", length.out = 30),
      Forecast = as.numeric(forecast_result$mean),
      Lower = as.numeric(forecast_result$lower[, 2]),
      Upper = as.numeric(forecast_result$upper[, 2])
    )
    
    # Create interactive forecast plot
    plot_ly() %>%
      add_trace(data = daily_data, x = ~Date, y = ~Daily_Close, 
                type = 'scatter', mode = 'lines', name = 'Historical Data', line = list(color = 'blue', width = 2)) %>%
      add_trace(data = forecast_df, x = ~Date, y = ~Forecast, 
                type = 'scatter', mode = 'lines', name = 'Forecast', line = list(color = 'red', width = 3)) %>%
      add_ribbons(data = forecast_df, 
                  x = ~Date, 
                  ymin = ~Lower, 
                  ymax = ~Upper, 
                  name = 'Confidence Interval', 
                  opacity = 0.2, fillcolor = 'rgba(255, 165, 0, 0.5)') %>%  # Orange fill color for the confidence interval
      layout(title = "30-Day Forecast of Daily Close Prices",
             xaxis = list(title = "Date"),
             yaxis = list(title = "Close Price (USD)"))
  })
  
}


# Run the application
shinyApp(ui = ui, server = server)