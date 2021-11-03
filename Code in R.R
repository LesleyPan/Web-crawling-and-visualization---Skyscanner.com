#This project is designed to automatically collect the information of cheap return air tickets on websites and visualize on map, with a certain origin city in certain whole month but no certain destination and travel date. I crawled the data of cheap air tickets from Skyscanner, which is one of the largest online travel agencies. Skyscanner.com is a behavior-based website, so here, I use Selenium to get the content of targeted pages. The geocoded data of destinations is gained from Google Map via its API service.

#There are mainly four steps with corresponding code and self-created functions in this project: 

#1) Initialize the Selenium and open the chorme browser

library(ggmap)
library(maps)
library(RSelenium)
library(rvest)
library(XML)
library(RCurl)
library(dplyr)
library(data.table)

remDr <- rsDriver(verbose = T,
                  browser = c('chrome'),
                  port = 4441L,
                  remoteServerAddr = "localhost",
                  chromever = "81.0.4044.69")

rm <- remDr$client

rm$getStatus()
```

# 2) Navigate to the targeted page and restructure it
 
 # When chrome opens the Skyscanner site first time, we need to accept the cookies firstly and switch the language to English to continue. Then when we reopen this site, there is no need to do both of them. So I created two functions in this phase for the first-time navigating and non-first-time navigating respectively, just in case we need to collect the data with different origin cities or monthes.
 # 
 # The initial inputs needed include: 
 #  - 4-letter short name of the origin city (check manually on the website firstly. We go to the targeted page directly instead of ging from homepage due to the facte that it is more easily to be asked to do the robot test when navigating the homepage)
 #  - 2 digits of targeted month for traveling(01/Jan - 12/Dec)
 #  - Whether prefer direct flights only
 # 
 # In order not to make the code too tedious, I only collect the information of the flight routes from the origin city to top-20 coutries with the cheapest airfares.
 
 
go_url_fun1 <- function(origin, month, direct = T){
  seturl <- paste0("https://www.skyscanner.com/transport/flights-from/",origin,"/?adults=1&children=0&adultsv2=1&childrenv2=&infants=0&cabinclass=economy&rtn=1&preferdirects=true&outboundaltsenabled=false&inboundaltsenabled=false&oym=20",month,"&iym=20",month,"&ref=home")
  rm$navigate(seturl)
  Sys.sleep(3)
  #Click "accept cookies"
  rm$findElement(using = "xpath",
                 value = '//*//div[@class="CookieBanner_CookieBanner__buttons-wrapper__zXGDH"]/button[1]')$clickElement()
  Sys.sleep(3)
  #Switch the language to English, since the default language could be Swedish if your IP is in Sweden
  rm$findElement(using = "xpath",
                 value = '//*//li[@id="culture-info"]/button[1]')$clickElement()
  Sys.sleep(3)
  rm$findElement(using = "xpath",
                 value = '//*//select[@id="culture-selector-locale"]')$clickElement()
  rm$findElement(using = "xpath",
                 value = '//*//button[@id="culture-selector-switch-to-english"]')$clickElement()
  Sys.sleep(1)
  rm$findElement(using = "xpath",
                 value = '//*//button[@id="culture-selector-save"]')$clickElement()
  #If prefer the direct flights, check this filter on this page
  if (direct == T) {
    Sys.sleep(5)
    rm$findElement(using = "xpath",
                   value = '//*//input[@id="filter-direct-stops-input"]')$clickElement()
  }
  Sys.sleep(5)
  #Click to unfold the information of all 20 countries in the search results so that we can get the specific routes between cities by using getPagesource
  for (i in 1:20) {
    rm$findElement(using = 'xpath',
                   value = paste0('//*//div[@class="result-list nav-content"]/ul[@class="progressive"]/li[',i,']'))$clickElement()
    Sys.sleep(5)
  }
  pagesource <- rm$getPageSource()
  #Restructure it and reture it
  tpage <- htmlParse(pagesource[[1]])
  return(tpage)
}



go_url_fun2 <- function(origin, month, direct = T){
  seturl <- paste0("https://www.skyscanner.com/transport/flights-from/",origin,"/?adults=1&children=0&adultsv2=1&childrenv2=&infants=0&cabinclass=economy&rtn=1&preferdirects=true&outboundaltsenabled=false&inboundaltsenabled=false&oym=20",month,"&iym=20",month,"&ref=home")
  rm$navigate(seturl)
  if (direct == T) {
    Sys.sleep(5)
    rm$findElement(using = "xpath",
                   value = '//*//input[@id="filter-direct-stops-input"]')$clickElement()
  }
  Sys.sleep(5)
  for (i in 1:20) {
    rm$findElement(using = 'xpath',
                   value = paste0('//*//div[@class="result-list nav-content"]/ul[@class="progressive"]/li[',i,']'))$clickElement()
    Sys.sleep(5)
  }
  pagesource <- rm$getPageSource()
  tpage <- htmlParse(pagesource[[1]])
  return(tpage)
}

 
# 3) Use Xpath to parse the content of the page and extract the data, including the city names and country names of the destinations as well as the lowest prices for each destinations. Then store all of the data into a data table.

get_price_fun <- function(tpage){
  list <- list()
  #Extrat the names of countries, cities and lowest prices
  for (i in 1:20) {
    country <- xpathSApply(tpage,
                           paste0("//*//li[@class='browse-list-category open'][",
                                  i,"]//div[@class='browse-data-route']/h3"),
                           xmlValue)
    city <- xpathSApply(tpage,paste0("//*//li[@class='browse-list-category open'][",
                        i,"]//div[@class='browse-data-entry trip-link']/h3"),xmlValue)
    price <- xpathSApply(tpage,paste0("//*//li[@class='browse-list-category open'][",
                         i,"]//div[@class='browse-data-entry trip-link']//span[@class='price flightLink']"),xmlValue)
    list[[i]] <- data.table(country,city,price)
  }
  #Conbine all of them in a data table and return it
  dt <- rbindlist(list)
  #Remove the routes without certain lowest prices on the page
  dt <- dt[grep('[0-9]', dt$price)]
  #Extract the digital part of prices that without currency unit
  dt$price <- as.integer(gsub("\\D","",dt$price))
  #Reorder the list to let the cheaper prices on the top
  dt <- dt[order(price)]
  return(dt)
}

# 4) Visualize the destinations of cheap flights and their prices on map

show_on_map <- function(dt_price, title, googlemap_apikey, origin){
  #Gain the geocoded data from google map and prepare the data for plotting
  register_google(googlemap_apikey)
  
  #conbine the names of city and country to get the accurate geocode
  dt_price <- dt_price %>%
    mutate(city_country = paste0(city, " ", country)) 
  
  geodata <- sapply(dt_price$city_country, geocode)
  origingeo <- data.frame(geocode(origin))
  df_geodata <- data.frame(t(geodata))
  dt_price$lon <- as.character(df_geodata$lon)
  dt_price$lat <- as.character(df_geodata$lat)
  dt_price <- dt_price %>%
    mutate(price = as.integer(price),
           lon = as.numeric(lon),
           lat = as.numeric(lat),
           price_group = as.factor(ifelse(price < 1000, "0-999kr",
                                ifelse(price < 1500, "1000-1499kr",
                                       ">1499kr"))),
           factor(price_group, levels = c("0-999kr","1000-1499kr",">1499kr")))
  #Plot it by using ggplot
  mapworld<-borders("world",colour = "gray50",fill="white")
  ggplot()+
    #Draw the map of the whole world
    mapworld+
    #Set a clean and nice background for the map
    theme(
      panel.background = element_rect(fill = "lightcyan1",
                                      color = NA),
      panel.grid = element_blank(),
      axis.text.x = element_blank(),
      axis.text.y = element_blank(),
      axis.ticks = element_blank(),
      axis.title.x = element_blank(),
      axis.title.y = element_blank()
    )+
    
    #Only show the fitted part of map instead of showing the whole world
    coord_fixed(xlim = c(min(dt_price$lon)-10, max(dt_price$lon)+10),
                ylim = c(min(dt_price$lat)-10, max(dt_price$lat)+10)) +
    
    #Make all the destinations
    geom_point(data = dt_price, 
               aes(x = lon, y = lat, size = price, color = price_group))+
    
    #Mark the origin city also
    geom_point(aes(x = origingeo[,1], y = origingeo[,2]), 
               shape = 5, fill = "yellow", size = 3)+
    guides(size = F) +
    labs(title = title, caption = "Currency = SEK (Swedish Krone)")
}
```


# Here, I present the results of the cheapest air tickets of stockholm and paris in this coming August.
rm$open()
stockholm_aug <- go_url_fun1("stoc", 08)
price_stockholm_aug <- get_price_fun(stockholm_aug)

head(price_stockholm_aug)

show_stockholm_aug <- show_on_map(price_stockholm_aug,
            "Cheap flights of Stockholm in August 2020",
            "AIzaSyDlhBk0JfP6Eyyy4sPInWCTg6G4NlXsMps",
            "stockholm")

#show_stockholm_aug
paris_aug <- go_url_fun2("pari", 08)
price_paris_aug <- get_price_fun(paris_aug)
```

head(price_paris_aug)

show_paris_aug <- show_on_map(price_paris_aug,
            "Cheap flights of Paris in August 2020",
            "AIzaSyDlhBk0JfP6Eyyy4sPInWCTg6G4NlXsMps",
            "paris")

#show_paris_aug

save.image("DSSS_Assignment1 results.RData")