# Web-crawling-and-visualization---Skyscanner.com

This project is designed to automatically collect the information of cheap return air tickets on websites and visualize on map, with a certain origin city in certain whole month but no certain destination and travel date. I crawled the data of cheap air tickets from Skyscanner, which is one of the largest online travel agencies. Skyscanner.com is a behavior-based website, so here, I use Selenium to get the content of targeted pages. The geocoded data of destinations is gained from Google Map via its API service.
There are mainly four steps with corresponding code and self-created functions in this project:

1) Initialize the Selenium and open the chorme browser
2) Navigate to the targeted page and restructure it

When chrome opens the Skyscanner site first time, we need to accept the cookies firstly and switch the language to English to continue. Then when we reopen this site, there is no need to do both of them. So I created two functions in this phase for the first-time navigating and non-first-time navigating respectively, just in case we need to collect the data with different origin cities or monthes.

The initial inputs needed include: - 4-letter short name of the origin city (check manually on the website firstly. We go to the targeted page directly instead of ging from homepage due to the facte that it is more easily to be asked to do the robot test when navigating the homepage) - 2 digits of targeted month for
traveling(01/Jan - 12/Dec) - Whether prefer direct flights only

In order not to make the code too tedious, I only collect the information of the flight routes from the origin city to top-20 coutries with the cheapest airfares.

3) Use Xpath to parse the content of the page and extract the data, including the city names and country names of the destinations as well as the lowest prices for each destinations. Then store all of the data into a data table.
4) Visualize the destinations of cheap flights and their prices on map

<img width="402" alt="1635937890(1)" src="https://user-images.githubusercontent.com/56775305/140050415-bbe91995-41a7-4080-b789-10212a594e2b.png">

<img width="494" alt="1635937951(1)" src="https://user-images.githubusercontent.com/56775305/140050528-45379972-3138-4e0f-b827-78ab0ce655ee.png">

