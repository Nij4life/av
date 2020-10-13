# av

**This is a parser for the site [av.by](https://cars.av.by/), but so far only works for cars**

## Specific options:
```
    -u, --url=URL                        This is the address of the page we need
    -t, --url_type=URL_TYPE              This is the information type from page which we need. (categories or products)
    -r, --recursive=RECURSIVE            You need recursive descent for subcategories. (true or false)
    -s, --skip_products=SKIP_PRODUCTS    Skip collecting product data. (true or false)
        --help                           Show this message
```
  
## launch example
```
- ruby parser.rb -u https://cars.av.by -t categories -r true -s true          # Собрать все дерево категорий
- ruby parser.rb -u https://cars.av.by -t categories -r true                  # Собрать все дерево категорий и сохранить продукты
- ruby parser.rb -u https://cars.av.by/acura -t categories                    # Собрать категорию "acura" и сохранить продукты
- ruby parser.rb -u https://cars.av.by/acura -t categories -r true -s true    # Собрать дерево подкатегорий для "acura"
- ruby parser.rb -u https://cars.av.by/acura -t categories -r true            # Собрать дерево подкатегорий для "acura" и сохранить продукты
- ruby parser.rb -u https://cars.av.by/acura/mdx -t categories                # Собрать категорию "acura -> mdx" и сохранить продукты
```