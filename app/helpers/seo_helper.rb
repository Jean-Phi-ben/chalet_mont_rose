# Référencement : URL canonique, description, Open Graph et données structurées
# schema.org (JSON-LD) du chalet.
module SeoHelper
  SITE_HOST  = "www.chaletmontrose.fr".freeze
  SITE_HOSTS = [ SITE_HOST, "chaletmontrose.fr" ].freeze
  SITE_URL   = "https://#{SITE_HOST}".freeze

  DEFAULT_DESCRIPTION = "Chalet de luxe pour 12 personnes à Saint-Gervais (Le Bettex), face au Mont-Blanc, " \
                        "entre Megève et Chamonix : sauna, bain nordique, salle de cinéma, conciergerie.".freeze

  # Photos mises en avant pour Google et les partages (les premières sont prioritaires).
  SHOWCASE_PHOTOS = %w[chalet-main.jpg vue-mont-blanc-chalet.jpg salon.jpg master-bedroom.jpg
                       bain-nordique-neige.jpg sauna-vue-sud.jpg salle-cine-ecran.jpg chalet-cuisine-book.jpg].freeze

  AMENITIES = [ "Sauna finlandais", "Bain nordique extérieur", "Salle de cinéma", "Salle de jeux",
                "Cheminée", "Plancher chauffant", "Cuisine équipée haut de gamme", "Cave à vins",
                "Terrasse panoramique vue Mont-Blanc", "Local à skis chauffé", "Parking privé",
                "Barbecue", "Buanderie", "Wi-Fi Starlink", "Linge de maison fourni", "Conciergerie" ].freeze

  def page_description
    content_for(:description).presence || DEFAULT_DESCRIPTION
  end

  def canonical_url
    "#{SITE_URL}#{request.path}"
  end

  def absolute_image_url(source)
    "#{SITE_URL}#{image_path(source)}"
  end

  # <script type="application/ld+json"> ; json_escape neutralise un éventuel « </script> ».
  def json_ld_tag(data)
    tag.script(json_escape(data.to_json).html_safe, type: "application/ld+json")
  end

  def vacation_rental_json_ld(cheapest_week_price: nil)
    {
      "@context" => "https://schema.org",
      "@type" => "VacationRental",
      "@id" => "#{SITE_URL}/#chalet",
      "name" => "Chalet Mont Rose",
      "description" => DEFAULT_DESCRIPTION,
      "url" => "#{SITE_URL}/",
      "image" => SHOWCASE_PHOTOS.map { |p| absolute_image_url(p) },
      "telephone" => "+33689064057",
      "email" => "chaletmontrose74@gmail.com",
      "priceRange" => cheapest_week_price ? "À partir de #{cheapest_week_price} € / semaine" : "Sur demande",
      "address" => {
        "@type" => "PostalAddress",
        "streetAddress" => "2417 route de Cupelin",
        "postalCode" => "74170",
        "addressLocality" => "Saint-Gervais-les-Bains",
        "addressRegion" => "Haute-Savoie",
        "addressCountry" => "FR"
      },
      "geo" => { "@type" => "GeoCoordinates", "latitude" => 45.8852955, "longitude" => 6.6892642 },
      "containedInPlace" => { "@type" => "Place", "name" => "Saint-Gervais-les-Bains, massif du Mont-Blanc" },
      "containsPlace" => {
        "@type" => "Accommodation",
        "additionalType" => "https://schema.org/House",
        "numberOfBedrooms" => 5,
        "numberOfBathroomsTotal" => 6,
        "occupancy" => { "@type" => "QuantitativeValue", "maxValue" => 12 },
        "floorSize" => { "@type" => "QuantitativeValue", "value" => 260, "unitCode" => "MTK" },
        "amenityFeature" => AMENITIES.map { |a| { "@type" => "LocationFeatureSpecification", "name" => a, "value" => true } }
      },
      "brand" => { "@type" => "Organization", "name" => "Chalet Mont Rose SARL" }
    }
  end

  # faqs : [[question, réponse], …] — mêmes textes que la FAQ affichée sur la page.
  def faq_json_ld(faqs)
    {
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => faqs.map do |question, answer|
        { "@type" => "Question", "name" => question,
          "acceptedAnswer" => { "@type" => "Answer", "text" => answer } }
      end
    }
  end
end
