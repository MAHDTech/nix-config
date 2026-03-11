import os

# Ensure the 'scripts' directory exists
os.makedirs("scripts", exist_ok=True)

# Create the 'html-parser2.py' file
with open("scripts/html-parser2.py", "w") as file:
    file.write("""
import requests
from bs4 import BeautifulSoup

# Function to parse HTML from a URL
def parse_html(url):
    response = requests.get(url)
    response.raise_for_status()  # Check if the request was successful
    soup = BeautifulSoup(response.text, 'html.parser')
    return soup

# Example usage
if __name__ == '__main__':
    url = 'https://example.com'
    soup = parse_html(url)
    print(soup.prettify())
""")
