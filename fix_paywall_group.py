#!/usr/bin/env python3
"""Moves the Premium group from the root group into the DailyTodo source group."""

PROJECT_PATH = "/Users/atakanortac/Desktop/origin2/DailyTodo.xcodeproj/project.pbxproj"
PREMIUM_UUID = "6DF0C9352F557BFF0043B887"

with open(PROJECT_PATH, "r") as f:
    content = f.read()

# 1. Remove Premium from the root group's children list
content = content.replace(
    f"\t\t\t\t{PREMIUM_UUID} /* Premium */,\n\t\t\t\t6DF0C9372F557C110043B887 /* Resources */,",
    f"\t\t\t\t6DF0C9372F557C110043B887 /* Resources */,"
)

# 2. Add Premium into the DailyTodo source group's children (after the App group entry)
DAILYTODO_SOURCE_GROUP = "6DC0CAAC2F5F7D0000A875ED"
APP_GROUP_ENTRY = "\t\t\t\t6DF0C92A2F557AE90043B887 /* App */,"
content = content.replace(
    APP_GROUP_ENTRY,
    APP_GROUP_ENTRY + f"\n\t\t\t\t{PREMIUM_UUID} /* Premium */,"
)

with open(PROJECT_PATH, "w") as f:
    f.write(content)

print("Premium group moved to DailyTodo source group.")
