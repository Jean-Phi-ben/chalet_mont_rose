import { application } from "controllers/application"

import AutosubmitController from "controllers/autosubmit_controller"
import CalendarController from "controllers/calendar_controller"
import CarouselController from "controllers/carousel_controller"
import DepositPercentController from "controllers/deposit_percent_controller"
import DropdownController from "controllers/dropdown_controller"
import ModalController    from "controllers/modal_controller"
import NavbarController   from "controllers/navbar_controller"
import NoteEditorController from "controllers/note_editor_controller"

application.register("autosubmit", AutosubmitController)
application.register("calendar", CalendarController)
application.register("carousel", CarouselController)
application.register("deposit-percent", DepositPercentController)
application.register("dropdown", DropdownController)
application.register("modal",    ModalController)
application.register("navbar",   NavbarController)
application.register("note-editor", NoteEditorController)
