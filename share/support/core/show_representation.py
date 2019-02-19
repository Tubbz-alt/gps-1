"""
This file provides support for displaying Ada representation clauses generated
by GNAT (-gnatR3js switch).
"""

import os
import json
import distutils.dep_util
import GPS
from gps_utils import in_ada_file, interactive


ATTRIBUTES = ["Size", "Object_Size", "Value_Size", "Alignment"]

REPRESENTATION_MARKS = {}
# A dictionnary that associates a source filename with a list of marks

HIGHLIGHTING = "Editor code annotations"


def _log(msg, mode="error"):
    """Facility logger"""
    GPS.Console("Messages").write(msg + "\n", mode=mode)


def get_json_file():
    """Return the current file and its json file if possible"""
    context = GPS.current_context()
    file = context.file().path

    if context.project():
        list_dir = context.project().object_dirs(False)
    else:
        list_dir = GPS.Project.root().object_dirs(False)

    if list_dir:
        objdir = list_dir[0]
    else:
        objdir = GPS.get_tmp_dir()
        _log("Could not find an object directory for %s, reverting to %s" %
             (file, objdir))
    json_file = os.path.join(objdir, os.path.basename(file)) + ".json"
    return file, json_file


def reset_state(file_name):
    """Clear representation information for file_name"""
    global REPRESENTATION_MARKS

    if file_name in REPRESENTATION_MARKS:

        # Remove special lines
        srcbuf = GPS.EditorBuffer.get(GPS.File(file_name))

        for (mark, lines) in REPRESENTATION_MARKS[file_name]:
            srcbuf.remove_special_lines(mark, lines)

        # Empty entry in the dictionary
        REPRESENTATION_MARKS[file_name] = []


def parse_value(component, name):
    """Check if this is a value else display the formula"""
    def compute_formula(elem):
        """Recursively build the formula"""
        if isinstance(elem, (int, long)):
            return str(elem)
        code = elem.get("code", "")
        operands = elem.get("operands", [])
        eval_list = [compute_formula(op) for op in elem["operands"]]
        if not code or not operands:
            return ""
        elif len(operands) == 1:
            return code + eval_list[0]
        elif code in ["max", "min"]:
            return code + "(" + ", ".join(eval_list) + ")"
        else:
            code = " " + code + " "
            return "(" + code.join(eval_list) + ")"

    try:
        value = int(str(component[name]).strip())
    except (TypeError, ValueError):
        value = compute_formula(component[name])
    return str(value)


def parse_record(object, indent):
    """Parse the json of a type record and return the representation"""
    record = object.get("record", [])
    if not record:
        return ""

    res = "%sfor %s use record\n" % (indent, object["name"])
    for component in record:
        name = component["name"]
        position = str(component["Position"])
        first_bit = parse_value(component, "First_Bit")
        size = parse_value(component, "Size")
        if first_bit and first_bit != "0":
            size = size + " + " + first_bit
        size = size + " - 1"
        res += ("%s   %s at %s range %s .. %s;\n" %
                (indent, name, position, first_bit, size))
    res += "%send record;\n" % indent
    return res


def parse_object(object, column):
    """Parse the json and return the representation clauses"""
    indent = " " * int(column)
    res = ""
    name = object["name"]
    for attr in ATTRIBUTES:
        val = object.get(attr, None)
        if val:
            val = parse_value(object, attr)
            res += "%sfor %s'%s use %s;\n" % (indent, name, attr, val)

    res += parse_record(object, indent)
    return res


def parse_location(object):
    """The location can be in one the following format:
    'file:line:column' => return line
    or 'fileA:lineA:columnA [fileB:lineB:columnB]' => return lineB
    """
    location = object["location"]
    if '[' in location:
        # Get the last locations we can have multiple '[file:line:column]'
        location = location.split()[-1][1:-1]
    return location.split(":")[1]


def insert_location(buf, line):
    """Black magic to find where the lines should be inserted"""
    # Find the indentation level of line
    loc = buf.at(line, 1)
    line_str = buf.get_chars(loc, loc.end_of_line())
    column = len(line_str) - len(line_str.lstrip())

    # Find where the current block finish
    insert_line = loc.block_end_line() + 1
    if insert_line == buf.end_of_buffer().line():
        # No current blocks found => we are lost, don't be smart
        insert_line = line + 1
    return insert_line, column


def edit_file(file_name, json_name):
    """Parse the json output and add the representation clauses in file_name"""
    global REPRESENTATION_MARKS
    if not os.path.isfile(json_name):
        _log("Aborting operation: Can't find %s" % json_name)
        return

    try:
        with open(json_name, 'r') as fp:
            content = json.load(fp)
    except ValueError:
        _log("Fail to parse %s the json is invalid or empty" % json_name)
        return

    buf = GPS.EditorBuffer.get(GPS.File(file_name))
    REPRESENTATION_MARKS[file_name] = []

    # A dictionnary that associates a line with a list of messages
    messages_maps = {}

    # Go through the json and fill the messages maps
    for object in reversed(content):
        line = parse_location(object)
        insert_line, column = insert_location(buf, int(line))
        representation = parse_object(object, column)
        # Don't add an empty line
        if representation.strip():
            if messages_maps.get(insert_line, []):
                messages_maps[insert_line].append(representation)
            else:
                messages_maps[insert_line] = [representation]

    # Minimize the number of added special lines by adding a single special
    # line with the concatenation the representations for a given line
    for keys in messages_maps.keys():
        representation = "\n".join(messages_maps[keys]).rstrip()
        mark = buf.add_special_line(keys, representation, HIGHLIGHTING)
        mark_num = (mark, len(representation))
        REPRESENTATION_MARKS[file_name].append(mark_num)


def on_exit(process, status, full_output):
    if status:
        _log(process.get_result())
    else:
        _log("... start parsing the json", mode="text")
        edit_file(process.file_name, process.json_name)


def show_representation_clauses(file_name, json_name):
    """Generate the json files if missing"""
    context = GPS.current_context()
    try:
        if context.project():
            prj = (' -P """%s"""' %
                   GPS.Project.root().file().name("Build_Server"))
        else:
            prj = " -a"
    except Exception:
        GPS.Console("Messages").write(
            "Could not obtain project information for this file")
        return

    if distutils.dep_util.newer(file_name, json_name):
        # Running -gnatR in a spec will fail with:
        # "cannot generate code for file list.ads (package spec)"
        # thus use the body.
        body_name = GPS.File(file_name).other_file().name("Build_Server")
        scenario = GPS.Project.root().scenario_variables_cmd_line("-X")
        cmd = 'gprbuild -q %s -f -gnatR3js -u """%s"""' % (prj, body_name)
        if scenario:
            cmd += ' ' + scenario
        _log("Generating %s ..." % json_name, mode="text")
        proc = GPS.Process(cmd, on_exit=on_exit, remote_server="Build_Server")
        proc.file_name = file_name
        proc.json_name = json_name
    else:
        edit_file(file_name, json_name)


#################################
# Register the contextual menus #
#################################

@interactive("Ada", in_ada_file,
             contextual="Representation/Show representation clauses",
             name="Show representation clauses")
def show_inactive_file():
    """Add special lines showing the representation clauses"""
    file_name, json_name = get_json_file()
    show_representation_clauses(file_name, json_name)


@interactive("Ada", in_ada_file,
             contextual="Representation/Hide representation clauses",
             name="Hide representation clauses")
def clear_display():
    """Clear the added special lines"""
    file_name, _ = get_json_file()
    reset_state(file_name)
