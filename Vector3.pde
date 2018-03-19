static class Vector3 {
  private float x, y, z;
  public static Vector3 zero = new Vector3(0, 0, 0);

  public Vector3(float _x, float _y, float _z) {
    x = _x;
    y = _y;
    z = _z;
  }

  public static Vector3 Normalize(Vector3 _v) {
    float nrm_x = (_v.x > 0) ? 1 : -1;
    float nrm_y = (_v.y > 0) ? 1 : -1;
    float nrm_z = (_v.z > 0) ? 1 : -1;
    return new Vector3(nrm_x, nrm_y, nrm_z);
  }

  public static Vector3 Cross(Vector3 _l, Vector3 _r) {
    float crs_x = (_l.y * _r.z) - (_l.z * _r.y);
    float crs_y = (_l.z * _r.x) - (_l.x * _r.z);
    float crs_z = (_l.x * _r.y) - (_l.y * _r.x);
    return new Vector3(crs_x, crs_y, crs_z);
  }

  public static float Dot(Vector3 _l, Vector3 _r) {
    return (_l.x * _r.x) + (_l.y * _r.y) + (_l.z * _r.z);
  }

  public static Vector3 Addition(Vector3 _v1, Vector3 _v2) {
    return new Vector3( (_v1.x + _v2.x), (_v1.y + _v2.y), (_v1.z + _v2.z) );
  }
  
  public void setX(float _x) {
    x = _x;
  }
  
  public void setY(float _y) {
    y = _y;
  }
  
  public void setZ(float _z) {
    z = _z;
  }
}