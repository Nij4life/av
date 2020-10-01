# av
**Parser for the site av.by**


## launch example
- ruby parser.rb
- ruby parser.rb -u https://cars.av.by -t category -r false -s true
- ruby parser.rb -u https://cars.av.by/acura -r true
- ruby parser.rb -u https://cars.av.by/acura/mdx -s false


## Specific options:
    -u, --url=URL                    This is the address of the page we need
    -t, --url_type=URL_TYPE          This is the information type from page which we need. (categories or products)
    -r, --recursive=RECURSIVE        You need recursive descent for subcategories. (true or false)
    -s, --skip_products=SKIP_PRODUCTSSkip collecting product data. (true or false)
    -h, --help                       Show this message
