# The list of log actions comes from the MU specification on audit reports, and the
# types of actions to capture.  We supplement the first part of the lsit with some
# additional actions that may be of interest.

module LogAction
  ADD = "Add"
  DELETE = "Delete"
  UPDATE = "Update"
  VIEW = "View"
  EXPORT = "Export"
end