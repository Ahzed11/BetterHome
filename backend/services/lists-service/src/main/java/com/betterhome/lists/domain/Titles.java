package com.betterhome.lists.domain;

/** Shared title rule for lists and items. */
final class Titles {

    private Titles() {}

    static String require(String title) {
        if (title == null || title.isBlank()) {
            throw new ListException.BadRequest("title must not be blank");
        }
        return title.trim();
    }
}
