-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2001-2005                       --
--                             AdaCore                               --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

--  General description of modules
--  ==============================
--
--  This package contains all the subprograms needed to register new modules in
--  GPS.
--
--  All the functionalities provided in GPS are organized into modules. Each
--  module can extensively modify the standard behavior of GPS (see below)
--
--  The modules should only interact with each other through the kernel,
--  never directly. This provides more flexibility, as well as room for future
--  extensions like dynamic modules.
--
--  The default modules provided in GPS (source editor, project editor,...)
--  are more closely integrated into the kernel than other external
--  modules. However, even these should ideally be fully replaceable with minor
--  source modification (for instance if one wants to override the default
--  source editor).
--
--  Each module is associated with a unique name. The names for some of the
--  default GPS modules are provided as constants in this package, so that it
--  is easy to check whether an action was initiated by one module or another.
--
--  Registering modules
--  ===================
--
--  All the modules must be registered with the kernel before they can do
--  anything. Register_Module should be called from gps.adb, and this
--  subprogram can then register new behaviors in GPS (see below "Registering
--  New Features")
--
--  This mechanism allows the kernel to be completely independent of the
--  specific modules, since it doesn't need to know in advance the exact list
--  of modules.
--
--  It is possible to dynamically register a module that hasn't been linked
--  with the GPS executable using the procedure Dynamic_Register_Module.
--  In order to register modules dynamically, the following conditions need
--  to be met:
--
--  - compile the kernel as a shared library, using project files.
--  - create the dynamic module, as a SAL, including elaboration code that
--    will be called by Dynamic_Register_Module
--
--   To load a module during GPS execution, use the command "insmod":
--
--   GPS> insmod vcs_cvs vcs__cvs
--
--  Contextual menus
--  ================
--
--   Here is a description of the sequence of events used to display contextual
--   menus in GPS:
--      - Each object that should have a contextual menu calls
--        Register_Contextual_Menu. The kernel will automatically setup
--        appropriate gtk callbacks.
--      - Whenever the user presses the right mouse button, the kernel will ask
--        the object to report the context in which the event occured (name of
--        selected file, selected project,...).
--      - Each of the registered module then has the opportunity to add entries
--        in the contextual menu, based on this context.
--      - The menu is displayed, and the callback for the selected menu item
--        will be called as usual.
--      - The menu is automatically destroyed, and the context freed, when the
--        action has finished executing.
--
--  Registering features
--  ====================
--
--   The behavior of the kernel and GPS itself can be modified extensively by
--   the modules, through a set of Register_* subprograms. This includes:
--      - Inserting new widgets in the MDI (either at startup or upon user
--        request)
--      - Adding new menus and toolbar icons
--      - Adding new contextual menu and new entries in existing menus
--      - Changing the default behavior of several standard functions, like
--        file edition, help file display, ... through Mime callbacks
--      - Adding new search contexts (see find_utils.ads in the vsearch module)
--      - Adding new predefined regular expressions in the search dialog
--      - Changing the way the current desktop is saved to disk and restored
--      - Changing what is displayed in tooltips in the editors
--      - Adding new attributes to projects, and the corresponding pages in the
--        project creation wizard or the project properties dialog.
--      - Adding new user-modifiable preferences (see gps-preferences.ads)
--      - Adding new supported languages (see language_handlers-gps.ads)
--        and the corresponding cross-referencing subprograms (same file)
--      - Each module can register new commands for the shell interpreter
--      - Adding key handlers, which have priority over other shortcuts
--
--   All these changes can be done locally in the module, and do not need any
--   modification to the rest of GPS itself (apart from registering the module
--   itself. This means that a user might choose not to load some of the
--   modules to simplify the GUI or to use less memory.

with Gdk.Event;
with Glib.Object;
with Glib.Values;
with Gdk.Types;
with Gtk.Image;
with Gtk.Handlers;
with Gtk.Menu_Item;
with Gtk.Selection;
with Gtk.Widget;
with Gtkada.MDI;
with Commands; use Commands;
with Commands.Interactive;
with Interfaces.C.Strings;
with GPS.Kernel.Actions; use GPS.Kernel.Actions;

package GPS.Kernel.Modules is

   Explorer_Module_Name           : constant String := "Explorer";
   Project_Editor_Module_Name     : constant String := "Project_Editor";
   Dependency_Browser_Module_Name : constant String := "Dependency_Browser";
   Project_Browser_Module_Name    : constant String := "Project_Browser";
   --  Names for the internal modules

   -----------
   -- Types --
   -----------
   --  See also the types defined in gps-kernel.ads

   package Context_Callback is new Gtk.Handlers.User_Callback
     (Glib.Object.GObject_Record, Selection_Context_Access);

   -------------------------
   -- Module manipulation --
   -------------------------

   procedure Register_Module
     (Module                  : in out Module_ID;
      Kernel                  : access Kernel_Handle_Record'Class;
      Module_Name             : String;
      Priority                : Module_Priority := Default_Priority;
      Default_Context_Factory : Module_Default_Context_Factory := null;
      Save_Function           : Module_Save_Function := null;
      Tooltip_Handler         : Module_Tooltip_Handler := null;
      Customization_Handler   : Module_Customization_Handler := null);
   --  Register a new module into GPS.
   --  If Module is null, a new module_id is created. Otherwise, the internal
   --  information stored in Module is changed. This allows you to store user
   --  data specific to each module, instead of using global variables.
   --
   --  Module_Name can be used by other modules to check whether they want to
   --  interact with this module.
   --
   --  Save_Function is an optional callback that will handle the saving of
   --  the given module.
   --
   --  Tooltip_Handler is an optional callback used to display tooltips.
   --  See description of Module_Tooltip_Handler in GPS.Kernel and procedure
   --  Compute_Tooltip below for more details.
   --
   --  Customization_Handler is called every time some customization has
   --  changed: initially after all modules are loaded, or every time a
   --  module adds a customization string. Only one XML node is passed to
   --  Customization_Handler every time.

   procedure Dynamic_Register_Module
     (Kernel      : access Kernel_Handle_Record'Class;
      Shared_Lib  : String;
      Module_Name : String;
      Success     : out Boolean);
   --  Register a module dynamically.
   --  Shared_Lib is the name of the shared library containing the module.
   --  It can either be a full name, or a short name, e.g. "vfs" for
   --  "libvfs.so".
   --  Module_Name is the name of the module, e.g. "vfs_module".
   --  This procedure assumes that Shared_Lib provides two routines called
   --  Module_Name & "_init" and Module_Name & "__register_module" with the
   --  following profiles:
   --
   --  type Module_Init is access procedure;
   --
   --  type Register_Module is access procedure
   --    (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class);
   --
   --  Success is set to True if the module could be successfully registered.

   function List_Of_Modules (Kernel : access Kernel_Handle_Record'Class)
      return GPS.Kernel.Module_List.List;
   --  Return the list of currently loaded modules.

   function Module_Name (ID : access Module_ID_Record'Class) return String;
   --  Return the name of the module registered as ID.

   procedure Free_Modules (Kernel : access Kernel_Handle_Record'Class);
   --  Free all the registered modules, and call Destroy for each of these.

   function Get_Priority
     (ID : access Module_ID_Record'Class) return Module_Priority;
   --  Return the current priority of ID

   ----------------------
   -- Desktop handling --
   ----------------------

   procedure Add_Default_Desktop_Item
     (Kernel   : access Kernel_Handle_Record'Class;
      Tag_Name : String;
      Position : Gtkada.MDI.Child_Position := Gtkada.MDI.Position_Default;
      Focus    : Boolean := False;
      Raised   : Boolean := False);
   --  Add an item to the default desktop.
   --  If Focus is True, then the widget will be given the focus, unless
   --  another widget is also registered later on with Focus set to True.
   --  If Raised is True and the child is docked, then this widget will appear
   --  on top unless another widget is also registered later on with Raised set
   --  to True and in the same Dock.
   --  It isn't possible currently to define a node with subnodes for specific
   --  data, so your Load_Desktop procedure should be ready to handle such a
   --  childless XML node (the most typical case).

   ----------------------
   -- Contextual menus --
   ----------------------

   type Context_Factory is access function
     (Kernel       : access Kernel_Handle_Record'Class;
      Event_Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Object       : access Glib.Object.GObject_Record'Class;
      Event        : Gdk.Event.Gdk_Event;
      Menu         : Gtk.Menu.Gtk_Menu) return Selection_Context_Access;
   --  This function should return the context associated with the contextual
   --  menu, when the mouse event Event happened on Widget.
   --  The mouse event occured in Event_Widget, and the contextual menu was
   --  registered for Object
   --  The object should also add its default entries into the menu, so that
   --  they always appear first in the menu. Note that the module will not be
   --  asked in the second step whether new entries should be added.
   --
   --  If null is returned, no contextual menu will be displayed.
   --
   --  The kernel is automatically set in the context.

   procedure Register_Contextual_Menu
     (Kernel          : access Kernel_Handle_Record'Class;
      Event_On_Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Object          : access Glib.Object.GObject_Record'Class;
      ID              : Module_ID;
      Context_Func    : Context_Factory);
   --  Register that Widget should be associated with a contextual menu.
   --  Whenever a right-button click happens inside Event_On_Widget, then the
   --  following will happen:
   --     - the kernel detects the event, and creates an empty menu.
   --     - it asks Object, through Context_Func, the exact context for the
   --       menu (selected file, ....)
   --     - it then asks each of the registered modules whether it wants to
   --       add new items to the menu, and let it do so (through the
   --       Contextual_Menu_Handler provided in Register_Module)
   --     - it then displays the menu
   --     - it finally cleans up the memory when the menu is hidden

   type Contextual_Menu_Label_Creator_Record is abstract tagged null record;
   type Contextual_Menu_Label_Creator is
     access all Contextual_Menu_Label_Creator_Record'Class;
   function Get_Label
     (Creator   : access Contextual_Menu_Label_Creator_Record;
      Context   : access Selection_Context'Class) return String is abstract;
   --  Create the name to use for a contextual menu.
   --  If this function returns the empty string, the menu will be filtered out

   type Custom_Expansion is access function
     (Context : access Selection_Context'Class) return String;
   --  Provide the custom expansion for %C when expanding a label. If the
   --  empty string is returned, the contextual entry will not be displayed

   procedure Register_Contextual_Menu
     (Kernel      : access Kernel_Handle_Record'Class;
      Name        : String;
      Action      : Action_Record_Access;
      Label       : String := "";
      Custom      : Custom_Expansion := null;
      Stock_Image : String := "";
      Ref_Item    : String := "";
      Add_Before  : Boolean := True);
   --  Register a new contextual menu entry to tbe displayed.
   --  This menu will only be shown when the filter associated with the Action
   --  matches. The name used in the menu will be Label (or Name if label isn't
   --  specified), interpreted with the usual parameter substitution:
   --     %f => current file basename
   --     %d => current directory
   --     %p => current project name
   --     %l => current line
   --     %c => current columns
   --     %a => current category
   --     %e => current entity name
   --     %i => current importing project
   --     %C => value returned by Custom (the menu will not appear if this
   --           returns the empty string or Custom is undefined)
   --  The label might contain a path to indicate submenus.
   --  Image will be added to the left of the contextual menu entry.
   --  Ref_Item is the name of another contextual menu (not a label), relative
   --  to which the menu should be placed. There is no garantee that the new
   --  entry will appear just before or just after that item, in particular if
   --  other entries had the same requirement.
   --  If Action is null, then a separator will be added to the contextual
   --  menu instead. It is added in a submenu if Label is not the empty string

   procedure Register_Contextual_Menu
     (Kernel      : access Kernel_Handle_Record'Class;
      Name        : String;
      Action      : Action_Record_Access;
      Label       : access Contextual_Menu_Label_Creator_Record'Class;
      Stock_Image : String := "";
      Ref_Item    : String := "";
      Add_Before  : Boolean := True);
   --  Same as above, except the label of the menu is computed dynamically

   procedure Register_Contextual_Menu
     (Kernel      : access Kernel_Handle_Record'Class;
      Name        : String;
      Action      : Commands.Interactive.Interactive_Command_Access;
      Filter      : GPS.Kernel.Action_Filter := null;
      Label       : access Contextual_Menu_Label_Creator_Record'Class;
      Stock_Image : String := "";
      Ref_Item    : String := "";
      Add_Before  : Boolean := True);
   --  Same as above, except the action to execute is defined internally
   --  When the command is executed, the Context.Context field will be set to
   --  the current selection context, and Context.Event to the event that
   --  triggered the menu.
   --  Action doesn't need to Push_State/Pop_State, nor handle unexpected
   --  exceptions, since this is already done by its caller. This keeps the
   --  code shorter.

   procedure Register_Contextual_Menu
     (Kernel      : access Kernel_Handle_Record'Class;
      Name        : String;
      Action      : Commands.Interactive.Interactive_Command_Access := null;
      Filter      : GPS.Kernel.Action_Filter := null;
      Label       : String := "";
      Custom      : Custom_Expansion := null;
      Stock_Image : String := "";
      Ref_Item    : String := "";
      Add_Before  : Boolean := True);
   --  Same as above, but the menu title is a string where %p, %f,... are
   --  substituted.
   --  A separator is inserted if Action is null and the Filter matches

   procedure Register_Contextual_Submenu
     (Kernel     : access Kernel_Handle_Record'Class;
      Name       : String;
      Label      : String := "";
      Filter     : GPS.Kernel.Action_Filter := null;
      Submenu    : Module_Menu_Handler := null;
      Ref_Item   : String := "";
      Add_Before : Boolean := True);
   --  Register a new submenu. Its contents can be computed dynamically by
   --  providing a Submenu callback. This can be left to null if all entries
   --  are added through Register_Contextual_Menu (in which case the call to
   --  Register_Contextual_Submenu can be used to position the parent menu
   --  where appropriate.
   --  Submenu is passed the submenu created for the item, so it doesn't need
   --  to create the submenu itself

   procedure Set_Contextual_Menu_Visible
     (Kernel  : access Kernel_Handle_Record'Class;
      Name    : String;
      Visible : Boolean);
   --  This procedure can be used to toggle the visibility of contextual menus.
   --  When a contextual menu was set as invisible, it will no longer appear

   function Get_Registered_Contextual_Menus
     (Kernel  : access Kernel_Handle_Record'Class)
      return GNAT.OS_Lib.String_List_Access;
   --  Return the list of registered contextual menus. The returned array must
   --  be freed by the caller

   --------------
   -- Tooltips --
   --------------

   procedure Compute_Tooltip
     (Kernel  : access Kernel_Handle_Record'Class;
      Context : Selection_Context_Access;
      Pixmap  : out Gdk.Gdk_Pixmap;
      Width   : out Glib.Gint;
      Height  : out Glib.Gint);
   --  Given a context, pointing to e.g an entity, the kernel will ask
   --  each of the registered modules whether it wants to display a tooltip.
   --  The first module to set Pixmap will stop the process.
   --  If no module wants to display a tooltip, Pixmap is set to null, and
   --  Width and Height are set to 0.

   -----------
   -- Menus --
   -----------

   type Dynamic_Menu_Factory is access procedure
     (Kernel  : access Kernel_Handle_Record'Class;
      Context : Selection_Context_Access;
      Menu    : access Gtk.Menu.Gtk_Menu_Record'Class);
   --  Callback that fills Menu according to Context.

   procedure Register_Menu
     (Kernel      : access Kernel_Handle_Record'Class;
      Parent_Path : String;
      Item        : Gtk.Menu_Item.Gtk_Menu_Item := null;
      Ref_Item    : String := "";
      Add_Before  : Boolean := True);
   --  Add new menu items to the menu bar, as a child of Parent_Path.
   --  Parent_Path should have a form like "/main_main/submenu".
   --  Menus will be created if they don't exist.
   --  This is considered as an absolute path, as if it always started with
   --  a '/'.
   --
   --  Item might be null, in which case only the parent menu items are
   --  created, and Add_Before applies to the deepest one instead of Item.
   --
   --  The new item is inserted either:
   --    - before Ref_Item if the latter is not the empty string and Add_Before
   --      is true
   --    - after Ref_Item if the latter is not the empty string and Add_Before
   --      is false
   --    - at the end of the menu
   --
   --  To register a separator, do the following:
   --      Mitem : Gtk_Menu_Item;
   --      Gtk_New (Mitem);
   --      Register_Menu (Kernel, "/Parent_Path", Mitem);

   procedure Register_Menu
     (Kernel      : access Kernel_Handle_Record'Class;
      Parent_Path : String;
      Text        : String;
      Stock_Image : String := "";
      Callback    : Kernel_Callback.Marshallers.Void_Marshaller.Handler;
      Command     : Command_Access := null;
      Accel_Key   : Gdk.Types.Gdk_Key_Type := 0;
      Accel_Mods  : Gdk.Types.Gdk_Modifier_Type := 0;
      Ref_Item    : String := "";
      Add_Before  : Boolean := True;
      Sensitive   : Boolean := True;
      Action      : Action_Record_Access := null);
   --  Same as the above, but creates the menu item directly, and connects the
   --  appropriate callback.
   --  If Command is not null, then a callback will be created to launch
   --  this command when the menu is activated. In this case, both Callback
   --  and Command will be called.
   --  Sensitive indicates whether the menu item is created sensitive or not.

   function Register_Menu
     (Kernel      : access Kernel_Handle_Record'Class;
      Parent_Path : String;
      Text        : String;
      Stock_Image : String := "";
      Callback    : Kernel_Callback.Marshallers.Void_Marshaller.Handler;
      Command     : Command_Access := null;
      Accel_Key   : Gdk.Types.Gdk_Key_Type := 0;
      Accel_Mods  : Gdk.Types.Gdk_Modifier_Type := 0;
      Ref_Item    : String := "";
      Add_Before  : Boolean := True;
      Sensitive   : Boolean := True;
      Action      : Action_Record_Access := null)
      return Gtk.Menu_Item.Gtk_Menu_Item;
   --  Same as above, but returns the menu item that was created.

   procedure Register_Dynamic_Menu
     (Kernel      : access Kernel_Handle_Record'Class;
      Parent_Path : String;
      Text        : String;
      Stock_Image : String := "";
      Ref_Item    : String := "";
      Add_Before  : Boolean := True;
      Factory     : Dynamic_Menu_Factory);
   --  Register a menu that will be generated using Factory.

   function Find_Menu_Item
     (Kernel : access Kernel_Handle_Record'Class;
      Path   : String) return Gtk.Menu_Item.Gtk_Menu_Item;
   --  Given an absolute path (see Register_Menu) for a menu item, return
   --  the underlying gtk menu item. Useful in particular to check or change
   --  the state of a menu item. Path is case insensitive

   ---------------------
   -- Toolbar buttons --
   ---------------------

   procedure Register_Button
     (Kernel  : access Kernel_Handle_Record'Class;
      Text    : String;
      Command : Command_Access := null;
      Image   : Gtk.Image.Gtk_Image := null;
      Tooltip : String := "");
   --  Add a button at the end of the toolbar.

   procedure Register_Button
     (Kernel   : access Kernel_Handle_Record'Class;
      Stock_Id : String;
      Command  : Command_Access := null;
      Tooltip  : String := "");
   --  Same as above but with a stock button

   -------------------------
   -- Drag'n'drop support --
   -------------------------

   My_Target_Url    : constant Guint := 0;
   Target_Table_Url : constant Gtk.Selection.Target_Entry_Array :=
     (1 => (Interfaces.C.Strings.New_String ("text/uri-list"),
            Gtk.Selection.Target_No_Constraint, My_Target_Url));

   procedure Drag_Data_Received
     (Object : access Glib.Object.GObject_Record'Class;
      Args   : Glib.Values.GValues;
      Kernel : GPS.Kernel.Kernel_Handle);
   --  Handle text/uri-list drop events by loading the corresponding projects
   --  or files. Assume the selection data contains a string representing a LF
   --  or CR/LF separated list of files.

end GPS.Kernel.Modules;
