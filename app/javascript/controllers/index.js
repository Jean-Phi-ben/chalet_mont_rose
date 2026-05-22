import { application } from "controllers/application"

import CarouselController from "controllers/carousel_controller"
import DropdownController from "controllers/dropdown_controller"
import ModalController    from "controllers/modal_controller"
import NavbarController   from "controllers/navbar_controller"

application.register("carousel", CarouselController)
application.register("dropdown", DropdownController)
application.register("modal",    ModalController)
application.register("navbar",   NavbarController)
