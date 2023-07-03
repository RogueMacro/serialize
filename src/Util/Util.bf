using System;
using System.Collections;
using System.Reflection;

namespace Serialize.Util
{
	static class Util
	{
		public static bool IsPrimitive(Type type)
		{
			for (let i in type.Interfaces)
			{
				if (i == typeof(ISerializeAsPrimitive))
					return true;
			}

			let generic = type as SpecializedGenericType;

			return type.IsPrimitive ||
				(type.IsEnum && !type.IsUnion) ||
				type == typeof(String) ||
				type == typeof(DateTime) ||
				generic?.UnspecializedType == typeof(Nullable<>) &&
				IsPrimitive(generic.GetGenericArg(0));
		}

		public static bool IsList(Type type)
		{
			for (let i in type.Interfaces)
			{
				if (i == typeof(ISerializeAsList))
					return true;
			}

			return (type is SpecializedGenericType &&
				(type as SpecializedGenericType).UnspecializedType == typeof(List<>)) ||
				type.IsArray;
		}

		public static bool IsMap(Type type)
		{
			return !IsPrimitive(type) && !IsList(type);
		}	
	}
}